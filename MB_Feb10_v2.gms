*SHUHAIB NAWAWI
*ELECTRIC SPACE HEATING BUILDING OPTIMIZATION
*MULTIPLE BUILDINGS; NO STORAGE
*VERSION 1: MIN AGGREGATE PD

Sets
        t         time in hours           / 1 * 8760 /
        tt(t)     winter heating hours    / 1*3500, 6500*8760 /
        j         building id             / 204,58,162,64,63,141,203,364,129,218,255,244,60,140,54,22,304,95,41,97,72,271,130,333,257,75,89,4,107,354,65,79,363,69,205,145,119,230,120,17,38,179,358,146,111,110,46,80,256,163,175,308,249,370,284,243,68,366,134,253,389,176,339,227,393,273,124,388,228,37,306,348,35,34,338,260,20,112,185,229,274,241,374,383,201,114,177,152,103,151,150,83,371,116,261,158,264,397,127,362,213,380,188,369,280,346,90,87,100,115,71,108,239,299,330,73,376,40,341,329,207,57,353,61,237,59,173,238,288,392,309,139,70,14,76,324,52,133,233,307,272,334,326,384,196,252,236,349,283,27,2,117,45,170,357,301,250,281,248,226,200,43,165,305,149,312,199,345,335,321,164,232,295,3,11,386,285,160,297,356,159,352,29,39,287,23,121,275,212,246,181,310,148,344,91,187,94,372,296,28,379,240,74,86,278,298,183,135,293,33,36,220,375,53,225,85,192,365,92,361,191,66,291,147,314,292,325,9,194,77,235,265,202,221,355,198,131,174,48,42,266,7,184,395,105,347,143,269,67,396,378,167,81,259,44,359,138,125,210,242,128,286,303,5,123,394,19,368,55,263,332,157,93,154,267,214,31,258,317,337,331,126,195,318,193,382,254,373,6,10,178,398,186,319,51,1,8,106,216,189,26,336,399,142,377,211,387,209,367,277,13,197,144,342,340,190,122,24,16,313,21,315,166,276,101,182,169,268,49,231,328,113,82,88,84,215,136,289,323,18,99,350,316,155,219,172,217,282,327,118,279,251,320,109,400,290,224,234,262,311,270,12,78,223,180,96,247,171,56,161,156,30,32,294,245,360,50,343,300,102,391/
        jj(j)     selected building       / 204,58,162,64,63,141,203,364,129,218,255,244,60,140,54,22,304,95,41,97,72,271,130,333,257,75,89,4,107,354,65,79,363,69,205,145,119,230,120,17,38,179,358,146,111,110,46,80,256,163,175,308,249,370,284,243,68,366,134,253,389,176,339,227,393,273,124,388,228,37,306,348,35,34,338,260,20,112,185,229,274,241,374,383,201,114,177,152,103,151,150,83,371,116,261,158,264,397,127,362,213,380,188,369,280,346,90,87,100,115,71,108,239,299,330,73,376,40,341,329,207,57,353,61,237,59,173,238,288,392,309,139,70,14,76,324,52,133,233,307,272,334,326,384,196,252,236,349,283,27,2,117,45,170,357,301,250,281,248,226,200,43,165,305,149,312,199,345,335,321,164,232,295,3,11,386,285,160,297,356,159,352,29,39,287,23,121,275,212,246,181,310,148,344,91,187,94,372,296,28,379,240,74,86,278,298,183,135,293,33,36,220,375,53,225,85,192,365,92,361,191,66,291,147,314,292,325,9,194,77,235,265,202,221,355,198,131,174,48,42,266,7,184,395,105,347,143,269,67,396,378,167,81,259,44,359,138,125,210,242,128,286,303,5,123,394,19,368,55,263,332,157,93,154,267,214,31,258,317,337,331,126,195,318,193,382,254,373,6,10,178,398,186,319,51,1,8,106,216,189,26,336,399,142,377,211,387,209,367,277,13,197,144,342,340,190,122,24,16,313,21,315,166,276,101,182,169,268,49,231,328,113,82,88,84,215,136,289,323,18,99,350,316,155,219,172,217,282,327,118,279,251,320,109,400,290,224,234,262,311,270,12,78,223,180,96,247,171,56,161,156,30,32,294,245,360,50,343,300,102,391/;
Sets
        c         regression coefficient  / c_cop_0, c_cop_1, c_d_0, c_d_conduction,
                                            c_d_convection, c_d_radiation, c_d_transient /
        d         EPW data parameter      / p_Ambient_K, p_Solar, p_Wind /;

*=== Define marginal damage factor [$/MWh] parameter
Parameter pMDF(t)/
$onDelim
$include Detroit_MDF.csv
$offDelim
/;

Parameter house_coeff(j,c)/
$onDelim
$include building_coeff_2.csv
$offDelim
/;

Parameter pTstatHeatKelvin     / 293 /;

Table EPW(t,d)
$onDelim
$include EPW_Detroit.csv
$offDelim
;                   

Parameter
pAmbientTemp(t)
pSolarGain(t)
pWind(t)
pHDCoeff_0(j)
pHDCoeff_conduction(j)
pHDCoeff_convection(j)
pHDCoeff_radiation(j)
pHDCoeff_transient(j)
;
  
pAmbientTemp(t) = EPW(t, 'p_Ambient_K');
pSolarGain(t) = EPW(t, 'p_Solar');
pWind(t) = EPW(t, 'p_Wind');
 
pHDCoeff_0(j) = house_coeff(j,'c_d_0');
pHDCoeff_conduction(j) = house_coeff(j,'c_d_conduction');
pHDCoeff_convection(j) = house_coeff(j,'c_d_convection');
pHDCoeff_radiation(j)  = house_coeff(j,'c_d_radiation');
pHDCoeff_transient(j)  = house_coeff(j,'c_d_transient');


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
    vHeatingDemand(jj,tt)
    vInternalKelvin(jj,tt)
    vHeatPumpElectricity(jj,tt)
    vRegHeatingDemand(jj,tt)
    vPeakDemand
    vEnvDamage(jj,tt)
    vElecCost(jj,tt)
    vCOP(tt)
    vAggElecDemand(tt)
    vAvgTemp(tt)
    vPD_cost
    vED_cost(jj)
    vE_cost(jj)
    vSumEnergy
    ;

*=== Define range of internal temp in Kelvin. To remove when running sensitivity
vInternalKelvin.lo(jj, tt) = pTstatHeatKelvin - E;
vInternalKelvin.up(jj, tt) = pTstatHeatKelvin + E;

Equations
    eObjFunc
    eHeatPumpCOP(jj,tt)
    eHDRegression(jj,tt)
    eFindPD(tt)
    eTempDiffConst(jj,tt)
    eEnvDamage(jj,tt)
    eElecCost(jj,tt)
    eSumTempDiff(jj)
    eAggElecDemand(tt)
    eAvgTemp(tt)
    eSumEnergy
    ePD_cost
    eED_cost
    eE_cost
    ;

*=== Objective function in $
eObjFunc.. vZ =e= vPD_cost + sum((jj,tt), vEnvDamage(jj,tt) + vElecCost(jj,tt));

*=== Regression heat demand equation
eHDRegression(jj,tt).. vHeatingDemand(jj,tt) =g= pHDCoeff_0(jj) + pHDCoeff_conduction(jj)*(vInternalKelvin(jj,tt) - pAmbientTemp(tt))
                                            + pHDCoeff_convection(jj)*pWind(tt)*(vInternalKelvin(jj,tt) - pAmbientTemp(tt))
                                            + pHDCoeff_radiation(jj)*pSolarGain(tt)
                                            + (pHDCoeff_transient(jj)*(vInternalKelvin(jj,tt) - vInternalKelvin(jj,tt-1)))$(ord(tt)>1);
                                            
*=== COP rule
eHeatPumpCOP(jj,tt).. vHeatPumpElectricity(jj,tt) =e= vHeatingDemand(jj,tt) / pCOP(tt);

*=== Equation to find peak demand
eFindPD(tt).. vPeakDemand =g= sum(jj, vHeatPumpElectricity(jj,tt));

*=== Hourly monetized damage
eEnvDamage(jj,tt)..vEnvDamage(jj,tt) =e= (pMDF(tt)/1000)*vHeatPumpElectricity(jj,tt);

*=== Hourly electricity cost
eElecCost(jj,tt)..vElecCost(jj,tt) =e= pElecTariff*vHeatPumpElectricity(jj,tt);

*=== Temp diff constraint
eTempDiffConst(jj,tt).. pTstatHeatKelvin - vInternalKelvin(jj,tt) =l= E;

*=== Sum T diff must be 0
eSumTempDiff(jj)..sum(tt, (pTstatHeatKelvin - vInternalKelvin(jj, tt))) =e= 0;

eSumEnergy.. vSumEnergy =e= sum((jj,tt), vHeatPumpElectricity(jj,tt));

eAggElecDemand(tt).. vAggElecDemand(tt) =e= sum(jj, vHeatPumpElectricity(jj,tt));

eAvgTemp(tt).. vAvgTemp(tt) =e= sum(jj, vInternalKelvin(jj,tt)) / 381;

ePD_cost.. vPD_cost =e= pMonPeakDemand*vPeakDemand;
eED_cost(jj).. vED_cost(jj) =e= sum(tt, vEnvDamage(jj,tt));
eE_cost(jj).. vE_cost(jj) =e= sum(tt, pElecTariff*vHeatPumpElectricity(jj,tt));


Model HP_MB_model2 includes all equations /all/;
Solve HP_MB_model2 using lp minimizing vZ;

$ontext
set counter /c1*c5/;
parameter report(counter, *);

loop(counter,

E = ord(counter);
Solve HP_MB_model using lp minimizing vZ;
report(counter, 'epsilon.K') = E;
report(counter, 'OF_cost.$') = vZ.l;


);
display report;
$offtext

*display vInternalKelvin.l;
display vPeakDemand.l;
display vPD_cost.l;
display vED_cost.l;
display vE_cost.l;
display vSumEnergy.l;

*=== Export to Excel
execute_unload 'results.gdx', t, vAggElecDemand.l, vAvgTemp.l ;
*execute 'gdxxrw.exe results.gdx o=MB_Agg_v1.xlsx var=vAggElecDemand.l rng=AggDemand!A1 var=vAvgTemp.l rng=AvgTemp!A1';
execute 'gdxxrw.exe results.gdx o=MB_Full_Detroit_v2.xlsx var=vAggElecDemand.l rng=HPe!A1 var=vAvgTemp.l rng=AvgTemp!A1';
