%% Import required files/functions/libraries
addpath(genpath('./libs/'));
addpath(genpath('./examples/'));
addpath(genpath('./coppa/'));

%% User Input
% State range
min_state = 10; %Minimum number of states
max_state = 10; %Maximum number of states
grid_steps = 5; %Size of increment between states

splitPercentage = 70; % Split Training Set
splitStable = 'yes'; %Options: 'yes','no'. Determines if data and test set is always identical or random
model = {'pfa';'dbn'}; %Options: 'hmm','pfa','dbn'
num_iter = [20 1]; %number of times EM is iterated | number of times the model will be initialized with different random values to avoid local optimum 
dataset = {'test' 'test-sametrace'}; %Options: 'sap','sap-small','bpi2013','test'
blow_up_data = 'no'; %Options: 'yes','no'. If to add new cases for each partial trace of the log or not
max_num_context = 5; %Options: any number > 0. Determines how many context attributes will be considered
learn_new_model = 'yes'; %Options: 'yes','no'
prediction_mode = 'distribution'; %Options: 'simple','distribution'. 'simple' not working at the moment
draw_model = 'no'; %Options: 'yes', 'no'. Shows model of bayesian network

num_models = numel(model);
num_datasets = numel(dataset);
result = cell(1,num_datasets);

for j=1:num_datasets
    result{j} = cell(num_models+1, 3); %+1 for ngram; 3 for accuracy, sensivity and specificity
    %% Load data set
    %Input Required: only discrete attributes (except timestamp)
    disp(['Loading dataset ' dataset{j}]);
    if strcmp(dataset{j},'sap')
        filename = './example/sap/SAP_P2P_COPPA_FULL.csv'; 
        delimiter = ';'; 
        timestamp_format = 'yyyy-MM-dd HH:mm:ss.SSSSSSS'; 
        CaseID = 1; Activity = 2; Timestamp = 3;    
    elseif strcmp(dataset{j},'sap-small')
        filename = './example/sap/SAP_P2P_COPPA_SMALL.csv'; 
        delimiter = ';'; 
        timestamp_format = 'yyyy-MM-dd HH:mm:ss.SSSSSSS'; 
        CaseID = 1; Activity = 2; Timestamp = 3;    
    elseif strcmp(dataset{j},'bpi2013')
        filename = './example/bpi2013/VINST cases closed problems_COPPA.csv';
        delimiter = ';'; 
        timestamp_format = 'yyyy-MM-dd''T''HH:mm:ssXXX'; 
        CaseID = 1; Activity = 2; Timestamp = 3;
    elseif strcmp(dataset{j},'bpi2012a')
        filename = './example/bpi2012/financial_log_application_process_ressourceContext.csv';
        delimiter = ';'; 
        timestamp_format = 'yyyy-MM-dd''T''HH:mm:ssXXX'; 
        CaseID = 1; Activity = 2; Timestamp = 3;
    elseif strcmp(dataset{j},'test-sametrace')
        filename = './example/data_sametrace.csv';
        delimiter = ';'; 
        timestamp_format = 'yyyy-MM-dd''T''HH:mm:ssXXX'; 
        CaseID = 1; Activity = 2; Timestamp = 3;
    else
        filename = './example/data.csv'; 
        delimiter = ';'; 
        timestamp_format = 'yyyy-MM-dd''T''HH:mm:ssXXX'; 
        CaseID = 1; Activity = 2; Timestamp = 3;
    end
    for i=1:num_models
        %Load and Prepare Data
        [dataTraining dataTesting unique_values N mapping] = prepare_data(filename, delimiter, timestamp_format,CaseID,Timestamp,Activity,splitPercentage, splitStable, model{i}, blow_up_data, max_num_context); 
        %% Define model and start learning
        if strcmp(learn_new_model,'yes')
            % Learn new model
            [bestoverallbnet bestoverallstate] = stategrid_learning(model{i}, N ,dataTraining,num_iter,min_state, max_state,grid_steps, unique_values);
            %save the best model on disk
            save_name = ['bestbnet_' model{i} '_' dataset{j} '.mat'];
            save(save_name,'bestoverallbnet');
        else
            % Load existing model from disk
            disp('Loading saved model');
            load_name = ['bestbnet_' model{i} '_' dataset{j} '.mat'];
            load(load_name, 'bestoverallbnet');
        end

        %% Draw Model
        if strcmp(draw_model,'yes')
            G = bestoverallbnet.dag;
            draw_graph(G);
        end
        %% Prediction
        if strcmp(prediction_mode,'simple')
            [pred rv acc] = prediction_simple(bestoverallbnet, dataTesting);
        else
            [pred rv] = prediction(bestoverallbnet, dataTesting);
        end

        [acc sens spec]  = score_model(pred, rv, model{i});
        result{j}{i,1} = acc;
        result{j}{i,2} = sens;
        result{j}{i,3} = spec;
    end
    %% N-Gram prediction for benchmark
    [pred_n rv_n] = prediction_ngram(dataTraining,dataTesting,unique_values);
    [acc_n sens_n spec_n] = score_model(pred_n, rv_n, 'n-gram');
    result{j}{num_models + 1,1} = acc_n;
    result{j}{num_models + 1,2} = sens_n;
    result{j}{num_models + 1,3} = spec_n;
end

disp('Results:');
for i=1:num_datasets
    disp(['    - Dataset: ' dataset{i}]);
    for j=1:num_models
        disp(['         - Model: ' model{j}]);
        disp(['               - Accuracy: ' num2str(result{i}{j,1}*100) '%']);
        disp(['               - Sensitivity: ' num2str(result{i}{j,2}*100) '%']);
        disp(['               - Specificity: ' num2str(result{i}{j,3}*100) '%']);
    end
        disp(['         - Model: ngram' ]);
        disp(['               - Accuracy: ' num2str(result{i}{num_models+1,1}*100) '%']);
        disp(['               - Sensitivity: ' num2str(result{i}{num_models+1,2}*100) '%']);
        disp(['               - Specificity: ' num2str(result{i}{num_models+1,3}*100) '%']);
end
        