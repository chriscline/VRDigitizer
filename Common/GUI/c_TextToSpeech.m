classdef c_TextToSpeech < handle
% c_TextToSpeech - class providing a wrapper around operating system text-to-speech functionality
%
% Example:
%	c_TextToSpeech.say('Hello, world'); % less efficient for repeated calls
% Or:
%	tts = c_TextToSpeech('doAsync',true,'doAllowInterruption',false); 
%	tts.say('Hello, world');

	properties
		Rate
		Volume
		doAsync
		doAllowInterruption
	end
	
	properties(Access=protected)
		synthesizer
		queue = {};
		queuePollTimer;
		queuePollTimerName = '';
		inprogArgs = [];
	end
	
	methods
		function o = c_TextToSpeech(varargin)
			c_TextToSpeech.addDependencies();
			
			p = inputParser();
			p.addParameter('Rate',0,@(x) isscalar(x) && x >= -10 && x <= 10); % see .NET documentation for details
			p.addParameter('Volume',100,@isscalar);
			p.addParameter('doAsync',false,@islogical);
			p.addParameter('doAllowInterruption',true,@islogical);
			p.parse(varargin{:});
			s = p.Results;
			
			for iF = 1:length(p.Parameters)
				if isprop(o,p.Parameters{iF})
					o.(p.Parameters{iF}) = s.(p.Parameters{iF});
				end
			end
			
			if ispc
				o.synthesizer = System.Speech.Synthesis.SpeechSynthesizer;
			else
				error('Non-windows platforms not yet supported');
			end
			
			% initialize queue
			o.queue = {};
			o.queuePollTimerName = ['TextToSpeechTimer' c_getOutputSubset(2,@fileparts,tempname)];
		end
		
		function addLexicon(o,varargin)
			p = inputParser();
			p.addParameter('path','',@ischar);
			p.parse(varargin{:});
			s = p.Results;
			
			if ~isempty(s.path)
				assert(exist(s.path,'file')>0,'File does not exist at %s',s.path);
				o.synthesizer.AddLexicon(System.Uri(s.path),'application/pls+xml');
			else
				error('No input specified');
			end
		end
		
		function say(o,varargin)
			p = inputParser();
			p.addRequired('String',@ischar);
			p.addParameter('Rate',o.Rate,@(x) isscalar(x) && x >= -10 && x <= 10);
			p.addParameter('Volume',o.Volume,@isscalar);
			p.addParameter('doAsync',o.doAsync,@islogical);
			p.addParameter('doAllowInterruption',o.doAllowInterruption,@islogical);
			p.parse(varargin{:});
			s = p.Results;
			
			o.queueSay_(s);
		end
	end
	
	methods(Access=protected)
		function say_(o,structIn)
			s = structIn;
			
			o.synthesizer.Volume = s.Volume;
			o.synthesizer.Rate = s.Rate;
			
			if s.doAsync
				o.synthesizer.SpeakAsync(s.String);
			else
				o.synthesizer.Speak(s.String);
			end
		end
		function queueSay_(o,structIn)
			o.queue{end+1} = structIn;
			o.queueTimerCallback_();
		end
		
		function queueTimerCallback_(o)
			if isempty(o.queue) 
				if ~isempty(o.queuePollTimer)
					stop(o.queuePollTimer);
					delete(o.queuePollTimer);
					o.queuePollTimer = [];
				end
				return;
			end
			
			doSpeakNext = false;
			if o.synthesizer.State == System.Speech.Synthesis.SynthesizerState.Ready
				% any previous speech finished
				o.inprogArgs = [];
				doSpeakNext = true;
			else
				% previous speech still ongoing
				assert(~isempty(o.inprogArgs)); % any previous speech should have gone through queue
				assert(~isempty(o.queue)); % shouldn't get here with an empty queue
				if o.inprogArgs.doAllowInterruption 
					% cancel previous
					o.synthesizer.SpeakAsyncCancelAll();
					doSpeakNext = true;
				else
					if isempty(o.queuePollTimer)
						o.queuePollTimer = timer(...
							'ExecutionMode','fixedSpacing',...
							'Name',o.queuePollTimerName,...
							'Period',0.1,...
							'TimerFcn',@(h,e) o.queueTimerCallback_());
						start(o.queuePollTimer);
					end
					doSpeakNext = false;
				end
			end
			
			if doSpeakNext
				o.inprogArgs = o.queue{1};
				o.say_(o.queue{1});
				o.queue(1) = [];
				o.queueTimerCallback_();
			end
		end
	end
	
	
	methods(Static)
		function addDependencies()
			persistent pathModified;
			if isempty(pathModified)
				if ispc
					NET.addAssembly('System.Speech');
					NET.addAssembly('System');
				end
				pathModified = true;
			end
		end
		
		function Say(varargin)
			tts = c_TextToSpeech();
			tts.say(varargin{:});
		end
		
		function testfn()
			tts = c_TextToSpeech('doAsync',true,'doAllowInterruption',false);
		
			tts.say('Start'); % should hear
			pause(2);
			tts.say('Blocking','doAsync',false); % should hear
			tts.say('After blocking'); % should hear
			pause(2);
			tts.say('Should not hear this','doAllowInterruption',true);
			pause(0.4);
			tts.say('Interruption');
			pause(2);
			tts.say('Should hear both this','doAllowInterruption',false);
			tts.say('and this');
			tts.say('and also this');
			tts.say('and finally this');
		end
	end
end