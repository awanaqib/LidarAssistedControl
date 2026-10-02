function [PostProcessingConfig,PreProcessingVariation,InputFiles,Modifications] = GetParametersForDLC1p2(SimulationMode)

% inputs
arguments
    SimulationMode    char {mustBeMember(SimulationMode,{'FeedbackOnly'})}  
end

% Process parameters
StartTime               = 60;       % [s]           time to start evaluation (all signals should be settled) 
WoehlerExponentSteel    = 4;        % [-]           typical value for steel
WoehlerExponentComposite= 10;        % [-]          typical value for composite material
PC_RefSpd               = 0.9089;  % [rad/s]       rated generator speed from ROSCO_v2d6.IN

% files
StatisticsFile      	= 'Statistics_SteadyStates.mat';

% Variation
PreProcessingVariation  = { 'URef',[4:2:24],'%02d';
                            'Seed',[1:6]   ,'%02d'};

% template files
InputFiles{1,1}         = 'IEA-10.0-198-RWT.fst';            % main file
InputFiles{2,1}         = 'IEA-10.0-198-RWT_ElastoDyn.dat';  % to adjust initial conditions
InputFiles{3,1}         = 'IEA-10.0-198-RWT_InflowFile.dat';          % to adjust wind speed


% new files to be modified
InputFiles{1,2}         = '<SimulationName>.fst';
InputFiles{2,2}         = '<SimulationName>_ElastoDyn.dat';
InputFiles{3,2}         = '<SimulationName>_InflowWind.dat';

% modifications in new files (for all Modes)
Modifications           = {
                        % OpenFAST: change time and link to new files
                        '1','I','TMax',                 num2str(600+StartTime)
                        '1','I','EDFile',               InputFiles{2,2}
                        '1','I','InflowFile',           InputFiles{3,2}                        
                        % ElastoDyn: adjust initial conditions
                        '2','I','BlPitch\((1|2|3)\)',   @(VariationValues)num2str(GetStatistics(StatisticsFile,'mean_BldPitch1',VariationValues(1)),'%5.2f')
                        '2','I','RotSpeed',             @(VariationValues)num2str(GetStatistics(StatisticsFile,'mean_RotSpeed' ,VariationValues(1)),'%5.2f')                        
                        % InflowWind: change wind type and link to turbulent wind file
                        '3','I','WindType  '            '4'
                        '3','I','FilenameRoot',	        @(VariationValues)strcat('../TurbulentWind/URef_',num2str(VariationValues(1),'%02d'),'_Seed_',num2str(VariationValues(2),'%02d'))                       
                        };



% PlotTimeResults
nURef       = length(PreProcessingVariation{1,2});
nSeed       = length(PreProcessingVariation{2,2});
for iURef = 1:nURef
    ID = iURef;
    PostProcessingConfig.Plots.BasicTimePlot{ID}.Enable     = 1;
    PostProcessingConfig.Plots.BasicTimePlot{ID}.Channels   = {'Wind1VelX';'BldPitch1';'RotSpeed';} ;
    PostProcessingConfig.Plots.BasicTimePlot{ID}.gca.xlim   = [0 600]+StartTime;
    PostProcessingConfig.Plots.BasicTimePlot{ID}.IndicesConsideredDataFiles = [1:nSeed]+(iURef-1)*nSeed;
end

% CalculateStatistics
PostProcessingConfig.CalculateStatistics = { 
    'mean'          @(Data,Time)mean(Data(Time>=StartTime)) {'Wind1VelX';'GenPwr'}
    'DEL_4'         @(Data,Time)CalculateDEL(Data(Time>=StartTime),Time(Time>=StartTime),WoehlerExponentSteel)      {'TwrBsMyt';'RotTorq'}
    'DEL_10'        @(Data,Time)CalculateDEL(Data(Time>=StartTime),Time(Time>=StartTime),WoehlerExponentComposite)  {'RootMyb1'}
    'Overshoot'     @(Data,Time)max(max(rpm2radPs(Data(Time>=StartTime))-PC_RefSpd)/PC_RefSpd,0) {'GenSpeed'}
    'Travel'        @(Data,Time)CalculatePitchTravel(Data,Time,StartTime) {'BldPitch1'}
    'max'           @(Data,Time)max(Data(Time>=StartTime)) {'GenTq'}    
    }; 

end