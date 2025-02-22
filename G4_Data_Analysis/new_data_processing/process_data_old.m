function process_data(exp_folder, processing_settings_file)
%% Load .mat file containing user defined s.settings. These include:
    
    % channel_order = {'LmR_chan', 'L_chan', 'R_chan', 'F_chan', 'Frame Position', 'LmR', 'LpR'}; %add faLmR below if desired (line 214)
    %specify time ranges for parsing and data analysis
    % data rate (in Hz) which all data will be aligned to
    % # seconds before start of trial to include
    % # seconds after end of trial to include
    % # seconds after start of trial to start data analysis
    % # seconds before end of trial to end data analysis
    % #conversion factor to convert to microseconds (1000000 if in seconds -TDMS timestamps are in micros)
    % whether all condition durations are the same (1) or not (0), for error-checking
    % The filename of the processed file being used 'G4_Processed_Data.mat';
    % whether using the combined command (1) or not (0)
    
    
        % Determine any parameters that need calculating based on settings or that
    % were not provided by the user

    if nargin==0
        exp_folder = uigetdir('C:/','Select a folder containing a G4_TDMS_Logs file');
        processing_settings_file = uigetfile('C:/','Select your processing settings file');
    end
    
    % Normalization settings - take from DA_plot_settings
%     if ~exist(processing_settings_file, 'var')
%         processing_settings_file = 'processing_settings.mat';
%     end
    s = load(processing_settings_file);
    channel_order = s.settings.channel_order;


    %specify time ranges for parsing and data analysis
    data_rate = s.settings.data_rate; % rate (in Hz) which all data will be aligned to
    pre_dur = s.settings.pre_dur; %seconds before start of trial to include
    post_dur = s.settings.post_dur; %seconds after end of trial to include
    da_start = s.settings.da_start; %seconds after start of trial to start data analysis
    da_stop = s.settings.da_stop; %seconds before end of trial to end data analysis
    time_conv = s.settings.time_conv; %converts seconds to microseconds (TDMS timestamps are in micros)
    common_cond_dur = s.settings.common_cond_dur; %sets whether all condition durations are the same (1) or not (0), for error-checking
    processed_file_name = s.settings.processed_file_name;
    hist_datatypes = s.settings.hist_datatypes; %{'Frame Position', 'LmR', 'LpR'};
    trial_options = s.settings.trial_options;
    faLmR = s.settings.enable_faLmR;
    condition_pairs = s.settings.condition_pairs;
    enable_pos_series = s.settings.enable_pos_series;
    pos_conditions = s.settings.pos_conditions;
    num_positions = s.settings.num_positions;
    data_pad = s.settings.data_pad;
    sm_delay = s.settings.sm_delay;
    manual_first_start = s.settings.manual_first_start;
    combined_command = s.settings.combined_command;
    max_prctile = s.settings.max_prctile;
    path_to_protocol = s.settings.path_to_protocol;
    percent_to_shift = s.settings.percent_to_shift;
    wbf_range = s.settings.wbf_range;
    wbf_cutoff = s.settings.wbf_cutoff;
    wbf_end_percent = s.settings.wbf_end_percent;

    if isfield(s.settings, 'cross_correlation_tolerance')
        corrTolerance = s.settings.cross_correlation_tolerance;
    else
        corrTolerance = .02;
    end

    if isfield(s.settings, 'flying')
        flying = s.settings.flying;
    else
        flying = 1;
    end

    if isfield(s.settings, 'remove_nonflying_trials')
        remove_nonflying_trials = s.settings.remove_nonflying_trials;
    else
        remove_nonflying_trials = 1;
    end

    if isfield(s.settings, 'duration_diff_limit')
        duration_diff_limit = s.settings.duration_diff_limit;
    else
        duration_diff_limit = .1;
    end
    
    if isempty(s.settings.summary_save_path)
        summary_save_path = exp_folder;
    else
        summary_save_path = s.settings.summary_save_path;
    end
    summary_filename = strcat(s.settings.summary_filename, '.txt');

    if isfield(s.settings, 'framePosPercentile')
        framePosPercentile = s.settings.framePosPercentile;
    else
        
        framePosPercentile = .98;
    end

    if isfield(s.settings, 'framePosTolerance')
        framePosTolerance = s.settings.framePosTolerance;
        
    else
        framePosTolerance = 1;
    end

    if isfield(s.settings, 'perctile_tol')
        perctile_tol = s.settings.perctile_tol;
        
    else
        perctile_tol = .02;
    end

    if isfield(s.settings, 'static_conds')
        static_conds = s.settings.static_conds;
    else
        static_conds = 0;
    end


    %Set which command we should be looking for in the log files
    if combined_command == 1
        command_string = 'Set control mode, pattern id, pattern function id, ao function id, frame rate';
    else
        command_string = 'start-display';
    end




    % Load TDMS file

    Log = load_tdms_log(exp_folder);
    
        %get indices for all datatypes - Any datatype not present in the
    %channel_order variable will return an empty index.
    Frame_ind = strcmpi(channel_order,'Frame Position');
    LmR_ind = find(strcmpi(channel_order,'LmR'));
    LpR_ind = find(strcmpi(channel_order,'LpR'));
    LmR_chan_idx = find(strcmpi(channel_order,'LmR_chan'));
    L_chan_idx = find(strcmpi(channel_order,'L_chan'));
    R_chan_idx = find(strcmpi(channel_order,'R_chan'));
    F_chan_idx = find(strcmpi(channel_order,'F_chan'));
    Current_idx = find(strcmpi(channel_order, 'current'));
    Volt_idx = find(strcmpi(channel_order, 'voltage'));
%    faLmR_ind = find(strcmpi(channel_order,'faLmR'));
    num_ts_datatypes = length(channel_order);
    num_ADC_chans = length(Log.ADC.Channels);
    

    metadata_file = fullfile(exp_folder, 'metadata.mat');
    

    
    % Metadata file contains list of conditions that were bad the first
    % time and re-run.
    if isfile(metadata_file)
        load(metadata_file)
        if isfield(metadata, 'trials_rerun')
            trials_rerun = metadata.trials_rerun;
        else
            trials_rerun = [];
        end
    else
        metadata = {};
        trials_rerun = [];
    end
    
     %load the order in which conditions were run, as well as the number of
    %conditions and reps
    [exp_order, num_conds, num_reps] = get_exp_order(exp_folder);
    total_exp_trials = num_conds*num_reps  + trial_options(1) + trial_options(3);
    if trial_options(2)
        total_exp_trials = total_exp_trials + ((num_conds*num_reps) - 1);
    end


    % Determine the start and stop times of each trial (if we want to create a
    % different method of doing this, just write a new module and plug it in
    % here)

    [start_idx, stop_idx, start_times, stop_times] = get_start_stop_times(Log, command_string, manual_first_start);
    [frame_movement_start_times] = get_pattern_movement_times(start_times, Log);
    
    % Returns a struct, times, with 8 fields. The start times, stop times,
    % start idx, and movement times for the original trials and the rerun
    % trials. Also determines if the experiment was ended early, and if so,
    % how many more trials are expected than were recorded
    [times, ended_early, num_trials_short] = separate_originals_from_reruns(start_times, stop_times, start_idx, ...
        trial_options, trials_rerun, num_conds, num_reps, frame_movement_start_times);
    
    %get order of pattern IDs (maybe use for error-checking?)
    [modeID_order, patternID_order] = get_modeID_order(combined_command, Log, times.origin_start_idx);
   

    %Determine start and stop times for different trial types (pre, inter,
    %regular). This also replaces start/stop times of trials marked as bad
    %during streaming with the start/stop times of the final re-run of that
    %trial so the correct data will be pulled later1`

    [num_trials, trial_start_times, trial_stop_times, ...
    trial_move_start_times,trial_modes, intertrial_start_times, intertrial_stop_times, ...
    intertrial_durs, times] = get_trial_startStop(exp_order, trial_options, ...
    times, modeID_order, time_conv, trials_rerun, ended_early);

    num_conds_short = num_trials - length(trial_start_times);

    %organize trial duration and control mode by condition/repetition
    [cond_dur, cond_modes,  cond_frame_move_time, cond_start_times, cond_gaps] = organize_durations_modes(num_conds, num_reps, ...
    num_trials, exp_order, trial_stop_times, trial_start_times,  ...
    trial_move_start_times, trial_modes, time_conv, ended_early, num_conds_short);


 % pre-allocate arrays for aligning the timeseries data
    [ts_time, ts_data, inter_ts_time, inter_ts_data] = create_ts_arrays(cond_dur, data_rate, pre_dur, post_dur, num_ts_datatypes, ...
    num_conds, num_reps, trial_options, intertrial_durs, num_trials);
    
%%%%%Maybe create wbf_data in a different function to include intertrials,
%%%%%then pass it in to the function to find bad wbfs where I only look at
%%%%%the indices for the actual condition???
    [bad_duration_conds, bad_duration_intertrials] = check_condition_durations(cond_dur, intertrial_durs, path_to_protocol, duration_diff_limit);
    if ~static_conds
        [bad_slope_conds] = check_flat_conditions(trial_start_times, trial_stop_times, Log, num_reps, num_conds, exp_order);
    else
        bad_slope_conds = [];
    end
    % if num_trials_short == 0
    %     [bad_crossCorr_conds] = check_correlation(trial_start_times, trial_stop_times, exp_order, Log, cond_modes, corrTolerance);
    % else
    %     bad_crossCorr_conds = [];
    % end
    frame_position_check = check_frame_position(path_to_protocol, start_times, stop_times, exp_order, ...
        Log, cond_modes, corrTolerance, framePosTolerance, framePosPercentile, perctile_tol);

    if remove_nonflying_trials && flying
        [bad_WBF_conds, wbf_data] = find_bad_wbf_trials(Log, ts_data, wbf_range, wbf_cutoff, ...
        wbf_end_percent, trial_start_times, trial_stop_times, num_conds, num_reps, exp_order, ...
        num_trials, num_conds_short);
    else
        bad_WBF_conds = [];
    end


    %check condition durations and control modes for experiment errors
%     assert(all(all((cond_modes-repmat(cond_modes(:,1),[1 num_reps]))==0)),...
%         'unexpected order of trial modes - check that pre-trial, post-trial, and intertrial options are correct')
    if all(all((cond_modes-repmat(cond_modes(:,1),[1 num_reps]))~=0))
        warning('unexpected order of trial modes - if the experiment was not ended early, check that pre-trial, post-trial, and intertrial options are correct.');
    end

%      %Generate report of bad conditions  
    [bad_conds, bad_reps, bad_intertrials, bad_conds_summary] = ...
        consolidate_bad_conds(bad_duration_conds, bad_duration_intertrials,...
        bad_WBF_conds, bad_slope_conds, num_trials, num_conds, num_reps, trial_options);
    
    if ~isempty(bad_conds)
        for c = 1:length(bad_conds)
            
            cond_frame_move_time(bad_conds(c), bad_reps(c)) = NaN;
           
        end
    end
    
    %loop for every trial
    for trial=1:num_trials-num_conds_short
        cond = exp_order(trial);
        rep = floor((trial-1)/num_conds)+1;

        %only process data for good trials
        if ~(any(cond==bad_conds) && any(rep==bad_reps(bad_conds==cond)))
            %get analog input data for this trial, aligned to data rate
            for chan = 1:num_ADC_chans
                start_ind = find(Log.ADC.Time(chan,:)>=(trial_start_times(trial)-pre_dur*time_conv),1);
                stop_ind = find(Log.ADC.Time(chan,:)<=(trial_stop_times(trial)+post_dur*time_conv),1,'last');
                if isempty(stop_ind)
                    stop_ind = length(Log.ADC.Time(chan,:));
                end
                unaligned_time = double(Log.ADC.Time(chan,start_ind:stop_ind) - trial_start_times(trial))/time_conv;
                ts_data(chan,cond,rep,:) = align_timeseries(ts_time, unaligned_time, Log.ADC.Volts(chan,start_ind:stop_ind), 'leave nan', 'mean');
            end

            %get frame position data for this trial, aligned to data rate
            start_ind = find(Log.Frames.Time(1,:)>=(trial_start_times(trial)-pre_dur*time_conv),1);
            stop_ind = find(Log.Frames.Time(1,:)<=(trial_stop_times(trial)+post_dur*time_conv),1,'last');
            if isempty(stop_ind)
                stop_ind = length(Log.Frames.Time(1,:));
            end
            unaligned_time = double(Log.Frames.Time(1,start_ind:stop_ind)-trial_start_times(trial))/time_conv;
            ts_data(Frame_ind,cond,rep,:) = align_timeseries(ts_time, unaligned_time, Log.Frames.Position(1,start_ind:stop_ind)+1, 'propagate', 'median');

            %create dataset for intertrial histogram (if applicable)
            if trial_options(2)==1 && trial<num_trials && ~(any(trial==bad_intertrials))
                %get frame position data, upsampled to match ADC timestamps
                start_ind = find(Log.Frames.Time(1,:)>=intertrial_start_times(trial),1);
                stop_ind = find(Log.Frames.Time(1,:)<=intertrial_stop_times(trial),1,'last');
                unaligned_time = double(Log.Frames.Time(1,start_ind:stop_ind)-intertrial_start_times(trial))/time_conv;
                inter_ts_data(trial,:) = align_timeseries(inter_ts_time, unaligned_time, Log.Frames.Position(1,start_ind:stop_ind)+1, 'propagate', 'median');
            else
                inter_ts_data = [];
            end
            
        end
    end
    
    ts_data = search_for_misaligned_data(ts_data, percent_to_shift, num_conds, num_reps, Frame_ind);
    
    if flying
         %% Normalize LmR timeseries data
    
        %Get maxs (do not normalize to baselines by default)    
    
        num_datapoints = size(ts_data, 4);
        
        maxs = get_max_process_normalization(max_prctile, ts_data,...
            num_conds, num_datapoints, num_ts_datatypes, num_reps);
    
        %Normalize all timeseries data  
        
        [ts_data_normalized, normalization_max] = normalize_ts_data(L_chan_idx, R_chan_idx, ts_data, maxs);
    
    
        %Get timeseries avg over reps - normalized and
        %unnormalized. 
        %% process data into meaningful datasets
        %calculate LmR (Left - Right) and LpR (Left + Right)
        
         
        
        %Unnormalized datasets
        ts_data(LmR_ind,:,:,:) = ts_data(L_chan_idx,:,:,:) - ts_data(R_chan_idx,:,:,:); % + = right turns, - = left turns
        ts_data(LpR_ind,:,:,:) = ts_data(L_chan_idx,:,:,:) + ts_data(R_chan_idx,:,:,:); % + = increased amplitude, - = decreased
        
        
        
        %Normalized datasets
        ts_data_normalized(LmR_ind,:,:,:) = ts_data_normalized(L_chan_idx,:,:,:) - ts_data_normalized(R_chan_idx,:,:,:); % + = right turns, - = left turns   
        ts_data_normalized(LpR_ind,:,:,:) = ts_data_normalized(L_chan_idx,:,:,:) + ts_data_normalized(R_chan_idx,:,:,:); % + = increased amplitude, - = decreased    
        
    
         %duplicate ts_data and exclude all datapoints outside data analysis
         %window. Shorten condition data to actual analysis window set. 
        da_data = ts_data;
    
        da_data_norm = ts_data_normalized;
        da_start_ind = find(ts_time>=da_start,1);
        da_data(:,:,:,1:da_start_ind) = nan; %omit data before trial start
        for con = 1:num_conds
            if ~isempty(find(con==bad_conds))
                continue;
            end
            da_stop_ind = find(ts_time<=(cond_dur(con,1)-da_stop),1,'last');
            assert(~isempty(da_stop_ind),'data analysis window extends past trial end')
            da_data(:,con,:,da_stop_ind:end) = nan; %omit data after trial end
            da_data_norm(:,con,:,da_stop_ind:end) = nan;
        end
    
    
        ts_avg_reps = squeeze(mean(da_data, 3, 'omitnan'));
        LmR_avg_over_reps = squeeze(ts_avg_reps(LmR_ind,:,:));
        LpR_avg_over_reps = squeeze(ts_avg_reps(LpR_ind,:,:));
        
        ts_avg_reps_norm = squeeze(mean(da_data_norm, 3, 'omitnan'));
        LmR_avg_reps_norm = squeeze(ts_avg_reps_norm(LmR_ind,:,:));   
        LpR_avg_reps_norm = squeeze(ts_avg_reps_norm(LpR_ind,:,:));
    
        %Generate flipped and averaged datasets if requested
           
        if faLmR == 1
            [faLmR_data, faLmR_data_norm] = get_faLmR(da_data, da_data_norm, LmR_ind, condition_pairs);
            faLmR_avg_over_reps = squeeze(mean(faLmR_data(:,:,:),2, 'omitnan'));
            faLmR_avg_reps_norm = squeeze(mean(faLmR_data_norm(:,:,:),2, 'omitnan'));
        else
            faLmR_data = [];
            faLmR_data_norm = [];
            faLmR_avg_over_reps = [];
            faLmR_avg_reps_norm = [];
        end
    
    %calculate values for tuning curves
        tc_data = mean(da_data,4, 'omitnan');
        tc_data_norm = mean(da_data_norm,4, 'omitnan');
        
        %calculate histograms of/by pattern position - normalized and
        %unnormalized
        if ~isempty(hist_datatypes)
            hist_data = calculate_histograms(da_data, hist_datatypes, Frame_ind, num_conds, num_reps,...
            LmR_ind, LpR_ind);
        else
            hist_data = [];
        end
        
        %get histogram of intertrial pattern position
        %get histogram of intertrial pattern position
        if trial_options(2) %if intertrials were run
            inter_hist_data = calculate_intertrial_histograms(inter_ts_data);
        else
            inter_hist_data = [];
        end
    
        
        %If included in settings, get the position series data from timeseries
        %data - normalized and unnormalized.
        if enable_pos_series
                
            [pos_series, mean_pos_series] = get_position_series(da_data_norm, ...
                Frame_ind, num_positions, data_pad, LmR_ind, sm_delay, pos_conditions);
    
    %         [pos_series, mean_pos_series] = get_position_series_a(ts_data, ...
    %             Frame_ind, num_positions, data_pad, LmR_ind, sm_delay, pos_conditions);
    
        else
            pos_series = [];
            mean_pos_series = [];
    
        end

        channelNames.timeseries = channel_order; %cell array of channel names for timeseries data
        channelNames.histograms = hist_datatypes; %cell array of channel names for histograms
        histograms_CL = hist_data; %[datatype, condition, repetition, pattern-position]
        interhistogram = inter_hist_data; %[repetition, pattern-position]
        timestamps = ts_time; %[1 timestamp]
        timeseries = da_data; %[datatype, condition, repition, datapoint]
        timeseries_normalized = da_data_norm;
        faLmR_timeseries = faLmR_data;
        faLmR_timeseries_normalized = faLmR_data_norm;
        summaries = tc_data; %[datatype, condition, repition]
        summaries_normalized = tc_data_norm;
        conditionModes = cond_modes(:,1); %[condition]
        pattern_movement_time_avg = squeeze(mean(cond_frame_move_time,2, 'omitnan'));
%       LmR_normalization_max = maxs(LmR_ind,1,1)

    
        save(fullfile(exp_folder,processed_file_name), 'timeseries', 'timeseries_normalized', ...
            'faLmR_timeseries', 'faLmR_timeseries_normalized', 'ts_avg_reps', 'ts_avg_reps_norm', ...
        'LmR_avg_over_reps', 'LmR_avg_reps_norm','LpR_avg_over_reps', 'LpR_avg_reps_norm',...
        'faLmR_avg_over_reps', 'faLmR_avg_reps_norm','inter_ts_data', 'channelNames', 'histograms_CL', ...
        'summaries', 'summaries_normalized','conditionModes', 'interhistogram', 'timestamps', ...
        'pos_series', 'mean_pos_series', 'pos_conditions', 'normalization_max', ...
        'frame_position_check', 'bad_duration_conds', 'bad_duration_intertrials', ...
        'bad_WBF_conds','bad_slope_conds', 'cond_frame_move_time', 'pattern_movement_time_avg', 'cond_start_times', 'cond_gaps');

    else
        da_data = ts_data;
        da_start_ind = find(ts_time>=da_start,1);
        da_data(:,:,:,1:da_start_ind) = nan; %omit data before trial start
        for con = 1:num_conds
            if ~isempty(find(con==bad_conds))
                continue;
            end
            da_stop_ind = find(ts_time<=(cond_dur(con,1)-da_stop),1,'last');
            assert(~isempty(da_stop_ind),'data analysis window extends past trial end')
            da_data(:,con,:,da_stop_ind:end) = nan; %omit data after trial end
        end

        ts_avg_reps = squeeze(mean(da_data, 3, 'omitnan'));
        tc_data = mean(da_data,4, 'omitnan');
        %get histogram of intertrial pattern position
        if trial_options(2) %if intertrials were run
            inter_hist_data = calculate_intertrial_histograms(inter_ts_data);
        else
            inter_hist_data = [];
        end

        channelNames.timeseries = channel_order; %cell array of channel names for timeseries data
        channelNames.histograms = hist_datatypes; %cell array of channel names for histogram
        interhistogram = inter_hist_data; %[repetition, pattern-position]
        timestamps = ts_time; %[1 timestamp]
        timeseries = da_data; %[datatype, condition, repition, datapoint]
        summaries = tc_data; %[datatype, condition, repition]
        conditionModes = cond_modes(:,1); %[condition]
        pattern_movement_time_avg = squeeze(mean(cond_frame_move_time,2, 'omitnan'));

        save(fullfile(exp_folder,processed_file_name), 'timeseries', 'ts_avg_reps',...
            'channelNames',  'summaries', 'conditionModes', 'inter_ts_data', 'interhistogram', ...
            'timestamps', 'bad_duration_conds', 'bad_duration_intertrials',...
             'cond_frame_move_time','frame_position_check', ...
            'pattern_movement_time_avg', 'cond_start_times', 'cond_gaps');


    end

    %% save data
    fileId = fopen(fullfile(summary_save_path,summary_filename), 'wt');
    for line = 1:length(bad_conds_summary)
        fprintf(fileId, '\n%s\n',bad_conds_summary{line});
    end
    fclose(fileId);
    

end