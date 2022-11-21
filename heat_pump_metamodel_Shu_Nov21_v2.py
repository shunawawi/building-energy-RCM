
"""

Last modified:  11/15 (added R2) 
                11/14 (addressed NoneType error)

"""

import pandas
import numpy
import math
from sklearn.linear_model import LinearRegression
#from sklearn import model_selection
#import sklearn.metrics as metrics
from ladybug.epw import EPW
from collections import OrderedDict



class city_data:
    '''
    stores the data and directories for a specific city
    '''
    def __init__(self, city_name):
        '''
        city_name = string of the city being examined (e.g., 'Spokane')
        '''
        self.city_name = city_name
        self.city_results_dir = root_dir+'project_singlefamily_detached_%s/localResults/'%self.city_name
        self.city_results = pandas.read_csv(self.city_results_dir + 'results.csv')
        self.city_results_base = self.city_results_base_wrangle()
        self.city_results_upgrade = self.city_results_upgrade_wrangle()[0]
        self.city_results_setback = self.city_results_upgrade_wrangle()[1]
        self.city_epw_df = self.epw_wrangle()
    
    def city_results_base_wrangle(self):
        #read in data for houses with baseline heating technology
        city_results_base = self.city_results[(self.city_results['apply_upgrade.run_measure']==0) & (self.city_results['apply_upgrade_2.run_measure']==0)]
        #remove houses that have heating types 'heat_pump' or 'none'
        city_results_base = city_results_base[(city_results_base['building_characteristics_report.hvac_system_heat_pump']=='None')&(city_results_base['building_characteristics_report.hvac_system_heating_none']=='None')]
        #get heater efficiencies
        city_results_base['h_afue'] = numpy.sum((city_results_base['building_characteristics_report.hvac_system_heating_fuel_oil'].map(lambda x: x.lstrip('Oil Boiler Furnace, Wall/Floor').rstrip('.AFUE %')).replace('None', 0).astype(int), city_results_base['building_characteristics_report.hvac_system_heating_natural_gas'].map(lambda x: x.lstrip('Gas Boiler Furnace, Wall/Floor').rstrip('.AFUE %')).replace('None', 0).replace('92.5', 92.5).astype(float), city_results_base['building_characteristics_report.hvac_system_heating_propane'].map(lambda x: x.lstrip('Propane Boiler Furnace, Wall/Floor').rstrip('.AFUE %')).replace('None', 0).astype(int), city_results_base['building_characteristics_report.hvac_system_heating_electricity'].replace('Electric Baseboard', 1).replace('Electric Furnace', 1).replace('Electric Boiler', 1).replace('None', 0).astype(int)), axis=0)
        #keep houses where the heat efficiency does not equal zero
        city_results_base = city_results_base[city_results_base['h_afue']!=0]
        #get the heating setpoint
        city_results_base['heat_setpoint'] = city_results_base['building_characteristics_report.heating_setpoint'].str.slice(0,2).astype(int) 
        return city_results_base
    
    def city_results_upgrade_wrangle(self):    
        #get the upgrade data: upgrade 1 gives the house a heatpump, upgrade 2 keeps the existing heater but has a twice-a-day thermostat setback to help simulate temporal temperature transients of the houses inside temperature
        city_results_upgrade = self.city_results[self.city_results['apply_upgrade.run_measure']==1]
        city_results_upgrade2 = self.city_results[self.city_results['apply_upgrade_2.run_measure']==1][['build_existing_model.building_id', '_id']]
        #create a new set of results that uses the characteristics of base but then the _id of upgrade_2 so we get a profile where inside temperature is changing
        city_results_setback = self.city_results_base.copy()
        city_results_setback.rename(columns={'_id': '_id_base'}, inplace=True)
        city_results_setback = city_results_setback.merge(city_results_upgrade2, on='build_existing_model.building_id', how='left') 
        return (city_results_upgrade, city_results_setback)
        
    def epw_wrangle(self):
        #read in and clean the weather data from the .epw file
        #get epw location and convert into dataframe (https://discourse.ladybug.tools/t/read-epw-file-into-a-pandas-dataframe/8984/3)
        city_epw_name = self.city_results['building_characteristics_report.location_weather_filename'].dropna().iloc[0]
        epwCls = EPW(r""+epw_dir + city_epw_name)
        epwDataList = epwCls.to_dict()['data_collections']
        epwDataDict = OrderedDict()
        for dataCol in  epwDataList:
            dataName = dataCol['header']['data_type']['name']
            epwDataDict[dataName] = dataCol['values']
        city_epw_df = pandas.DataFrame(epwDataDict)
        city_epw_df['ambient_kelvin'] = city_epw_df['Dry Bulb Temperature'] + 273.15
        return city_epw_df





class regression_model:
    '''
    uses the data stored in the city_data class to find a linear regression relating:
        1) cop of the heat pump as a function of the temperature difference between inside and ambient temperature
        2) demand of the heat pump as a function of internal temperature, ambient temperature, wind speed, solar radiation, and the internal temperature during the previous hour. Each of these effects has a coefficient. The coefficients roughly represent conduction, convection, radiation, and thermal inertia
    '''
    def __init__(self, city_data):
        '''
        city_data = class structure holding the required data
        '''
        #generic data
        self.city_data = city_data
        self.coefficients_master_df = pandas.DataFrame(columns=['city_name', 
                                                                'house_id', 
                                                                'c_cop_0', 
                                                                'c_cop_1', 
                                                                'c_d_0', 
                                                                'c_d_conduction', 
                                                                'c_d_convection', 
                                                                'c_d_radiation', 
                                                                'c_d_transient', 
                                                                'error_demand',
                                                                'model_R2'])     
        self.iterate_through_houses()

    def iterate_through_houses(self):
        #loop through the houses, calculate the regression coefficients, concatenate them together into one dataframe
        i=0
        for house_id in self.city_data.city_results_base['build_existing_model.building_id'].unique().astype(int):
            i+=1
            if (i % round(len(self.city_data.city_results_base)/20,0)) == 0:
                print ('   :' + str(math.ceil(i/len(self.city_data.city_results_base)*100)) + '% of houses solved for')
            self.update_regression_log(house_id)
        self.coefficients_master_df.reset_index(drop=True, inplace=True)
    
    def update_regression_log(self, house_id):
        #calculate the regression coefficients for an individual house and concatenate back to the master dataframe
        regression_fit_cop_house = self.regression_fit_cop(house_id)
        regression_fit_demand_house = self.regression_fit_demand(house_id)
        #package the results into a dataframe of the same form as coefficients_master_df
        coeff_df_add = pandas.DataFrame({'city_name': self.city_data.city_name, 
                                         'house_id': house_id, 
                                         'c_cop_0': regression_fit_cop_house[0], 
                                         'c_cop_1': regression_fit_cop_house[1],
                                         'c_d_0': regression_fit_demand_house[0], 
                                         'c_d_conduction': regression_fit_demand_house[1], 
                                         'c_d_convection': regression_fit_demand_house[2], 
                                         'c_d_radiation': regression_fit_demand_house[3], 
                                         'c_d_transient': regression_fit_demand_house[4],
                                         'error_demand': regression_fit_demand_house[5],
                                         'model_R2': regression_fit_demand_house[6]}, index = [0])
        #add the results back to the master
        self.coefficients_master_df = pandas.concat([self.coefficients_master_df, coeff_df_add])
    
    def regression_fit_cop(self, house_id):
        #calculates the linear regression fit of heat pump COP as a function of the temperature difference between inside and ambient temperature
        try:
            base_dir = self.city_data.city_results_base[self.city_data.city_results_base['build_existing_model.building_id']==house_id]['_id'].iloc[0]
            upgrade_dir = self.city_data.city_results_upgrade[self.city_data.city_results_upgrade['build_existing_model.building_id']==house_id]['_id'].iloc[0]
            h_8760_base_df = pandas.read_csv(self.city_data.city_results_dir+base_dir+'/results_csv/enduse_timeseries.csv')
            h_8760_upgrade_df = pandas.read_csv(self.city_data.city_results_dir+upgrade_dir+'/results_csv/enduse_timeseries.csv')
            #use the baseline heater efficiency to convert hourly heating energy consumed into hourly heating demand
            h_afue = self.city_data.city_results_base[self.city_data.city_results_base['build_existing_model.building_id']==house_id]['h_afue'].iloc[0]
            if h_afue == 1.0: #if it's electric heating
                h_8760_upgrade_df['heating_demand_kWh'] = h_8760_base_df['electricity_heating_kwh']
            else: #if it's fossil fuel, we want to ignore the electricity_heating_kwh, because that just encompasses fan/pump energy
                h_8760_upgrade_df['heating_demand_kWh'] = (h_8760_base_df['fuel_oil_heating_mbtu']*293.07 + h_8760_base_df['propane_heating_mbtu']*293.07 + h_8760_base_df['natural_gas_heating_therm']*29.30) / (h_afue/100.)
            #print(h_8760_upgrade_df['heating_demand_kWh'] )
            #pdb.set_trace()
            #use the heat pump energy consumption and the baseline heating demand to get the COP
            h_8760_upgrade_df['cop'] = h_8760_upgrade_df['heating_demand_kWh'] / (h_8760_upgrade_df['electricity_heating_kwh']+1e-8)
            #find the cop coefficients
            inside_fahrenheit = self.city_data.city_results_base[self.city_data.city_results_base['build_existing_model.building_id']==house_id]['heat_setpoint'].iloc[0]
            inside_kelvin = (inside_fahrenheit-32)*(5/9) + 273.15
            cop_model_df = pandas.DataFrame({'cop':h_8760_upgrade_df['cop'], 'deltaT':(inside_kelvin - self.city_data.city_epw_df['ambient_kelvin']), 'heating_demand_kWh':h_8760_upgrade_df['heating_demand_kWh']})
            #drop some of the outlier hours
            cop_model_df = cop_model_df[cop_model_df['heating_demand_kWh']>0.0] 
            #drop hours with very high COP values. These can occur because ResStock reports results on a hourly time resolution, so hours with very little demand might just be startup or shutdown effects from previous or future time periods
            cop_model_df = cop_model_df[(cop_model_df['cop']<=cop_model_df['cop'].quantile(0.95)) & (cop_model_df['heating_demand_kWh']>=cop_model_df['heating_demand_kWh'].quantile(0.05))] 
            regression = LinearRegression()
            X = cop_model_df['deltaT'].values.reshape(-1,1)
            Y = cop_model_df['cop'].values.reshape(-1,1)
            regression.fit(X, Y)
            c_cop_0 = regression.intercept_[0]
            c_cop_1 = regression.coef_[0][0]
            return (c_cop_0, c_cop_1)
        except:
            pass
  
    def regression_fit_demand(self, house_id):
        #calculates the multiple regression fit of demand of the heat pump as a function of internal temperature, ambient temperature, wind speed, solar radiation, and the internal temperature during the previous hour
        try:
            setback_dir = self.city_data.city_results_setback[self.city_data.city_results_setback['build_existing_model.building_id']==house_id]['_id'].iloc[0]
            h_8760_setback_df = pandas.read_csv(self.city_data.city_results_dir+setback_dir+'/results_csv/enduse_timeseries.csv')
            #use the baseline heater efficiency to convert hourly heating energy consumed into hourly heating demand
            h_afue = self.city_data.city_results_base[self.city_data.city_results_base['build_existing_model.building_id']==house_id]['h_afue'].iloc[0]
            if h_afue == 1.0: #if it's electric heating
                h_8760_setback_df['heating_demand_kWh'] = h_8760_setback_df['electricity_heating_kwh']
            else: #if it's fossil fuel, we want to ignore the electricity_heating_kwh, because that just encompasses fan/pump energy
                h_8760_setback_df['heating_demand_kWh'] = (h_8760_setback_df['fuel_oil_heating_mbtu']*293.07 + h_8760_setback_df['propane_heating_mbtu']*293.07 + h_8760_setback_df['natural_gas_heating_therm']*29.30) / (h_afue/100.)
            #compile the different data that the regression model will find coefficients for
            #inside temperature
            h_8760_setback_df.rename(columns={'ZONE MEAN AIR TEMPERATURE (LIVING ZONE) [F]':'inside_fahrenheit'}, inplace=True)
            h_8760_setback_df['inside_kelvin'] = (h_8760_setback_df['inside_fahrenheit']-32)*(5/9) + 273.15
            #outside temperature
            h_8760_setback_df['ambient_kelvin'] = self.city_data.city_epw_df['ambient_kelvin']
            #temperature delta
            h_8760_setback_df['delta_kelvin'] = numpy.maximum(0.0, h_8760_setback_df['inside_kelvin'] - h_8760_setback_df['ambient_kelvin'])
            #temperature delta X wind speed
            h_8760_setback_df['delta_kelvin_wind'] = h_8760_setback_df['delta_kelvin'] * self.city_data.city_epw_df['Wind Speed']
            #solar
            h_8760_setback_df['solar'] = self.city_data.city_epw_df['Global Horizontal Radiation'] + self.city_data.city_epw_df['Direct Normal Radiation'] + self.city_data.city_epw_df['Diffuse Horizontal Radiation']
            #transient
            h_8760_setback_df['delta_kelvin_transient'] = h_8760_setback_df['inside_kelvin'].diff().fillna(0.0)
            #regression model
            demand_model_df = pandas.DataFrame({'heating_demand_kWh':h_8760_setback_df['heating_demand_kWh'],
                                                'delta_kelvin': h_8760_setback_df['delta_kelvin'],
                                                'delta_kelvin_wind': h_8760_setback_df['delta_kelvin_wind'],
                                                'solar': h_8760_setback_df['solar'],
                                                'delta_kelvin_transient': h_8760_setback_df['delta_kelvin_transient']})
            #drop some of the outlier hours
            demand_model_df = demand_model_df[demand_model_df['heating_demand_kWh']>0.0] 
            #use multiple regression to solve for the coefficients
            regression_demand = LinearRegression()
            #print(demand_model_df)
            X_demand = demand_model_df[['delta_kelvin', 'delta_kelvin_wind', 'solar', 'delta_kelvin_transient']].values.reshape(-1,4)
            Y_demand = demand_model_df['heating_demand_kWh'].values.reshape(-1,1)
            regression_demand.fit(X_demand, Y_demand)
            c_d_0 = regression_demand.intercept_[0]
            c_d_conduction = regression_demand.coef_[0][0]
            c_d_convection = regression_demand.coef_[0][1]
            c_d_radiation = regression_demand.coef_[0][2]
            c_d_transient = regression_demand.coef_[0][3]
            #calculate the error
            demand_model_df['equation'] = c_d_0 + c_d_conduction*demand_model_df['delta_kelvin'] + c_d_convection*demand_model_df['delta_kelvin_wind'] + c_d_radiation*demand_model_df['solar'] + c_d_transient*demand_model_df['delta_kelvin_transient']
            error_demand = numpy.absolute(demand_model_df['equation'] - demand_model_df['heating_demand_kWh']).sum() / demand_model_df['heating_demand_kWh'].sum()
            #get regression R2
            R2_model = regression_demand.score(X_demand, Y_demand)
            #sample to help visualize annual hourly heat demand
            # global sample_demand_model
            #sample_demand_model = demand_model_df
            #return everything
            return (c_d_0, c_d_conduction, c_d_convection, c_d_radiation, c_d_transient, error_demand, R2_model)
        except:
            pass

    
     

    
if __name__ == '__main__':       
    #define the directories        
    global root_dir
    global epw_dir
    global city_data_temp
    root_dir = 'C:/Users/shuha/OneDrive/Desktop/PhD Research/National ResStock Data/'
    epw_dir = 'C:/Users/shuha/Downloads/project_resstock_national/' 
    #create an empty dictionary to hold the results
    results_metamodel = dict()
    #loop through the cities and find the regression coefficients  
    for city_name in ['Detroit']:
        print (city_name)
        print ('reading data')
        city_data_temp = city_data(city_name)
        print ('solving regression model for each house')
        regression_model_temp = regression_model(city_data_temp)
        city_coefficients = regression_model_temp.coefficients_master_df
        results_metamodel[city_name] = city_coefficients