*SHUHAIB NAWAWI
*ELECTRIC SPACE HEATING BUILDING OPTIMIZATION
*SINGLE BUILDING; NO STORAGE
*vRegHeatingDemand(tt) >= HD

Sets
        t       time in hours            / 1 * 8760 /
        tt(t)   winter heating hours     / 1*3500, 6500*8760 /
        d       EPW data parameter       / p_Ambient_K, p_Solar, p_Wind /;
        ;

Table EPW(t,d)
$onDelim
$include EPW_Detroit.csv
$offDelim
;                   

*=== Define weather parameters
Parameters
pAmbientTemp(t)
pSolarGain(t)
pWind(t)
;

pAmbientTemp(t) = EPW(t, 'p_Ambient_K');
pSolarGain(t) = EPW(t, 'p_Solar');
pWind(t) = EPW(t, 'p_Wind');

*=== Define marginal damage factor [$/MWh] parameter
Parameter pMDF(t)/
$onDelim
$include Detroit_MDF.csv
$offDelim
/;

*=== Use regression coefficient for Building #197 in Detroit 
*=== Can update thermostat setpoint temperature
Parameters 
    pCOP(t)    
    pHDCoeff_0  / -4.4408 /
    pHDCoeff_conduction / 1.0666 /
    pHDCoeff_convection / 0.0218 /
    pHDCoeff_radiation  / -0.0028 /
    pHDCoeff_transient  / 0.3339 /
    pTstatHeatKelvin     / 292 /
    ;

*=== Use segmented linear regression with 2 breakpoints
Parameter pCOP(t)/
$onDelim
$include COP.csv
$offDelim
/;

Scalar
pMonPeakDemand  / 26.76 /
pElecTariff     / 0.177 /
E               / 1 /
;

Variables
    vZ
    ;

Positive variables
    vHeatingDemand(tt)
    vInternalKelvin(tt)
    vHeatPumpElectricity(tt)
    vHeatingDemand(tt)
    vPeakDemand
    vEnvDamage(tt)
    vCOP(tt)
    vPD_cost
    vED_cost
    vE_cost
    vTdiff_sum
    ;

*=== Define range of internal temp in Kelvin. To remove when running sensitivity
*vInternalKelvin.lo(tt) = pTstatHeatKelvin - E;
*vInternalKelvin.up(tt) = pTstatHeatKelvin + E;

*vTdiff_sum.lo = 0;
*vTdiff_sum.up = 0;

Equations
    eObjFunc
    eHeatPumpCOP(tt)
    eHDRegression(tt)
    eFindPD(tt)
    eEnvDamage(tt)
    eSumTempDiff
    ePD_cost
    eED_cost
    eE_cost
    ;

*=== Objective function in $
eObjFunc.. vZ =e= vPD_cost + sum(tt, vEnvDamage(tt) + pElecTariff*vHeatPumpElectricity(tt));

*=== Regression heat demand equation
eHDRegression(tt).. vHeatingDemand(tt) =g= pHDCoeff_0 + pHDCoeff_conduction*(vInternalKelvin(tt) - pAmbientTemp(tt))
                                            + pHDCoeff_convection*pWind(tt)*(vInternalKelvin(tt) - pAmbientTemp(tt))
                                            + pHDCoeff_radiation*pSolarGain(tt)
                                            + (pHDCoeff_transient*(vInternalKelvin(tt) - vInternalKelvin(tt-1)))$(ord(tt)>1);
                                            
*=== COP rule
eHeatPumpCOP(tt).. vHeatPumpElectricity(tt) =e= vHeatingDemand(tt) / pCOP(tt);

*=== Equation to find peak demand
eFindPD(tt).. vPeakDemand =g= vHeatPumpElectricity(tt);

*=== Equation for monetized damage
eEnvDamage(tt).. vEnvDamage(tt) =e= (pMDF(tt)/1000)*vHeatPumpElectricity(tt);

*=== Sum T diff must be 0
*eSumTempDiff.. sum(tt, (pTstatHeatKelvin - vInternalKelvin(tt))) =e= 0;
eSumTempDiff.. sum(tt, (pTstatHeatKelvin - vInternalKelvin(tt))) =e= vTdiff_sum;

ePD_cost.. vPD_cost =e= pMonPeakDemand*vPeakDemand ;
eED_cost.. vED_cost =e= sum(tt, vEnvDamage(tt));
eE_cost.. vE_cost =e= sum(tt, pElecTariff*vHeatPumpElectricity(tt));

Model HP_model_v7 includes all equations /all/;
*Solve HP_model_v7 using lp minimizing vZ;

*$onText
set counter /E0*E3/;
parameter report(counter, *);

loop(counter,

E = ord(counter)-1;
*=== Define range of internal temp in Kelvin
vInternalKelvin.lo(tt) = pTstatHeatKelvin - E;
vInternalKelvin.up(tt) = pTstatHeatKelvin + E;
Solve HP_model_v7 using lp minimizing vZ;
report(counter, 'epsilon.K') = E;
report(counter, 'OF_cost.$') = vZ.l;
report(counter, 'PD_cost.$') = vPD_cost.l;
report(counter, 'ED_cost.$') = vED_cost.l;
report(counter, 'E_cost.$') = vE_cost.l;
report(counter, 'PD.kWh') = vPeakDemand.l;
report(counter, 'Sum_T.K') = vTdiff_sum.l;
);
display report;
*$OffText

display vInternalKelvin.l;
display vHeatPumpElectricity.l;
display vEnvDamage.l;
display vPeakDemand.l;

*=== Export to Excel
*execute_unload 'results.gdx', t, vInternalKelvin.l, vHeatingDemand.l,vHeatPumpElectricity.l, vEnvDamage.l, vHeatingDemand.l;
*execute 'gdxxrw.exe results.gdx o=293K_c5.xlsx var=vInternalKelvin.l rng=Temp!A1';
*execute 'gdxxrw.exe results.gdx o=E1_Feb10.xlsx var=vInternalKelvin.l rng=Temp!A1 var=vHeatingDemand.l rng=HD!A1 var=vHeatPumpElectricity.l rng=HP!A1 var=vEnvDamage.l rng=Damage!A1';
