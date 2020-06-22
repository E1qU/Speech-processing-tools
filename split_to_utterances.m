% Author: Einari Vaaras, einari.vaaras@tuni.fi, Tampere Univerity
% SPECOG, http://www.cs.tut.fi/sgn/specog/index.html

% The program splits audio files consisting of speech signals
% into separate utterances based on Short-Time Energy (STE). Please note
% that the program has been built for 48 kHz audio data, so minor
% modifications to the parameters are necessary for using data with some 
% other sampling rate. This program utilizes the STE calculation
% implementation made by Nabin Sharma:
% Nabin S Sharma (2020). Short-time Energy and Zero Crossing Rate 
% (https://www.mathworks.com/matlabcentral/fileexchange/23571-short-time-energy-and-zero-crossing-rate), 
% MATLAB Central File Exchange. Retrieved February 12, 2019.


% PLEASE CHANGE THE LINES 154-156 to name the created utterance files as
% you wish.

% Parameters:
% EDIT THESE TO YOUR NEEDS
files = dir('emotional_data/*.WAV'); % The directory of the WAV files

sequence_length_STE = 0.25;    % STE sequence length in seconds, 250 ms as default

highpass_frequency = 50;    % 50 Hz as the highpass filtering frequency

wintype = 'hamming';    % Window type for STE

winlen = 481;   % Window length for STE (480 samples is 10 ms for fs = 48 kHz)

median_length = 1;  % Median filtering is performed for the STE result.
                    % median_length is the length of the sequence (in seconds) of which 
                    % the median is always calculated.
                    
speech_threshold = 1/40; % Set a fortieth (default) of the median value of the median
                         % filtered result as the threshold that determines when speech
                         % is present. Depends on the amplitude of the data, modify for
                         % your needs. 1/40 is a good guess for speech with good amplitude
                         % balance, i.e. speech is not too quiet nor it is too loud.
                        
discard_length = 1.0;   % Discard audio clips that are shorter than 1.0 seconds (default).
                        % Typically shorter audio clips are sounds of people inhaling/exhaling,
                        % coughing, sneezing etc.
                        
wav_save_dir = 'emotional_data_split/';    % Directory for saving the utterances
                    

% Index for WAV file order number, to be used for WAV file naming
order_index = 0;

% Create a waitbar
f = waitbar(0,'Splitting into utterances...');

% Go through all the files
for k = 1:length(files)
    
    % The name of the file using its full directory path
    name = [files(k).folder,'\',files(k).name];
    
    % Read audio file
    [y,fs] = audioread(name);
    
    % Initialize variables
    E_tot = [];
    t_tot = [];
    t_0 = 0;
    
    % 0.25 seconds as the sequence length (default)
    sequence_length = fs*sequence_length_STE;
    
    % Determine how many chunks of 0.25 seconds are there in the audio file
    chunks = floor(length(y)/sequence_length);
    
    % Calculate the Short-Time Energy (STE) for every chunk
    for i = 0:chunks-1
        x = y(((sequence_length*i)+1) : ((sequence_length*(i+1))+1));
        
        % Highpass-filter the signal, 50 Hz (default) as the passband frequency
        x = highpass(x, highpass_frequency, fs);
        
        N = length(x); % signal length
        n = 0:N-1;
        ts = n*(1/fs); % time for signal
        
        
        % STE calculation
        
        winamp = [0.5,1]*(1/winlen);
        
        % find the STE
        E = energy(x,wintype,winamp(2),winlen);
        
        % time index for the STE after delay compensation
        out = (winlen-1)/2:(N+winlen-1)-(winlen-1)/2;
        t = (out-(winlen-1)/2)*(1/fs);
        t = t + t_0;
        t_0 = t(end);
        t_tot = [t_tot t];
        E_tot = [E_tot E(out)];
        
    end
        
    % Median filtering, median of 48k samples (default)
    E_tot_medfilt = medfilt1(E_tot,fs*median_length);
        
    % Set a fortieth (default) of the median value of the median filtered 
    % result as the threshold that determines when speech is present
    threshold = median(E_tot_medfilt)*speech_threshold;
    
    E_tot_medfilt(E_tot_medfilt < threshold) = 0;
    E_tot_medfilt(E_tot_medfilt >= threshold) = 1;
       
    % If there are zeros for more than 250 ms (12k samples), than it is usually
    % treated as a pause in speech. Thus, a threshold of 0.25 s is chosen to
    % determine the maximum length of a pause in speech. The central part of
    % the pause in speech is the timestamp where the signal is split into
    % separate sections.
    silence_threshold = fs/4;
    
    transitions = diff([0, E_tot_medfilt == 0, 0]); % Find where the array goes from non-zero to zero and vice versa
    runstarts = find(transitions == 1); % The places where the starts of the transitions occur
    runends = find(transitions == -1); % The places where the ends of the transitions occur
    runlengths = runends - runstarts;
    
    speech_pause_indeces = zeros(length(runlengths),1);
    for j = 1:length(runlengths)
        if runlengths(j) > silence_threshold
            speech_pause_indeces(j) = 1;
        end
    end
    
    % Remove the pauses that are too short
    runstarts = runstarts(logical(speech_pause_indeces));
    runends = runends(logical(speech_pause_indeces));
    clipping_parts = round((runends + runstarts)/2);
    
    % Add the last tick just in case if the last audio segment would
    % otherwise be left out. Remove 1/2 of window size from the added value
    % to avoid exceeding array bounds (rare but possible).
    clipping_parts(end+1) = t_tot(end)*fs - floor(winlen/2); 
    
    % Convert to integers
    clipping_parts = floor(clipping_parts);
    
    
    % Clip the audio signal into segments, save the segments as WAV files
    for i = 1:(length(clipping_parts)-1)
        sound_sequence = y(clipping_parts(i):clipping_parts(i+1),:);
        
        % Don't do anything if the segment is too short ( < 1.0 seconds, default)
        if length(sound_sequence) < discard_length*fs
            continue
        else
            % Create a new name, CHANGE THESE LINES FOR YOUR OWN NEED
            name_base_parts = split(files(k).name,'_');
            new_name = [wav_save_dir, name_base_parts{1}, '_', ...
                num2str(order_index), '_', name_base_parts{3}];
            
            % Save the audio segment with the new name
            audiowrite(new_name,sound_sequence,fs)
            
            % Increase order index by one
            order_index = order_index + 1;
        end
    end
    
    % Update the waitbar
    waitbar(k/length(files),f)
end

% Delete the waitbar
delete(f)



