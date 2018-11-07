classdef VRDigitizerInterfacer < handle

	%% Instance variables
	properties
		nc;
		doDebug;
		msgBufferLength;
		pollPeriod;
		XYZOffset;
		doRemapAxes;
		trackerKeys;
		prevMsg = [];
		callback_btn_triggerPressed;
		callback_btn_gripPressed;
		callback_btn_menuPressed;
		callback_btn_trackpadUpPressed;
		callback_btn_trackpadDownPressed;
		callback_btn_trackpadLeftPressed;
		callback_btn_trackpadRightPressed;
		callback_btn_touchTrackpadUpPressed;
		callback_btn_touchTrackpadDownPressed;
		callback_btn_touchTrackpadLeftPressed;
		callback_btn_touchTrackpadRightPressed;
		callback_btn_triggerReleased;
		callback_btn_gripReleased;
		callback_btn_menuReleased;
		callback_btn_trackpadUpReleased;
		callback_btn_trackpadDownReleased;
		callback_btn_trackpadLeftReleased;
		callback_btn_trackpadRightReleased;
		callback_btn_touchTrackpadUpReleased;
		callback_btn_touchTrackpadDownReleased;
		callback_btn_touchTrackpadLeftReleased;
		callback_btn_touchTrackpadRightReleased;
		callback_disconnected;
		callback_connected;
		callback_trackingChange;
		assumeDroppedAfterTime;
	end

	properties(Constant,Access=protected)
		printPrefix = 'VRDigitizer: ';
		buttonNames = {'trigger','grip','menu','touchTrackpadUp','trackpadUp','touchTrackpadDown','trackpadDown','touchTrackpadLeft','trackpadLeft','touchTrackpadRight','trackpadRight'};
		buttonStateNums = [0		1		2			3				4				5				6				7					8				9					10	];
		closeConnectionNum = 11;
		maxNumTrackedDevices = 5;
	end
	
	properties(Constant)
		trackedDeviceKeys = {'controller','controller2','tracker','tracker2','hmd'}; % order should match IDs specified in pyopenvr_helper (starting at 0)
		distUnit = 'm';
	end
	
	properties(SetAccess=protected)
		maxMsgLength;
		doPollAutomatically;
		pollerIsPaused = false;
		parsedMsgTemplate;
		allTrackerKeys;
	end
	
	properties(Dependent)
		trackerTransforms; % these are used to bring other trackers into the same coord system as the first. I.e. trackerTransform(:,:,1) should equal identity
		hasTrackerTransforms;
	end
	
	properties(Access=protected)
		doExpectQuaternions;
		partialMsgBuffer;
		msgBuffer;
		mutex_buffer = false;
		mutex_timerCallbackRunning = false;
		tmr
		timeOfLastMessage = [];
		trackerKeys_;
		trackerTransforms_;
	end
	
	%% Instance methods
	methods
		%% constructor
		function o = VRDigitizerInterfacer(varargin)

			p = inputParser();
			p.addParameter('doDebug',false,@islogical);
			p.addParameter('ip','127.0.0.1',@ischar);
			p.addParameter('port',3947,@isscalar);
			p.addParameter('msgBufferLength',1e3,@isscalar);
			p.addParameter('pollPeriod',0.1,@isscalar); 
			p.addParameter('doPollAutomatically',false,@islogical);
			p.addParameter('doRemapAxes',true,@islogical);
			p.addParameter('doExpectQuaternions',false,@islogical);
			p.addParameter('XYZOffset',[],@isvector); % calibrated offset from center of controller to stylus tip
			for iB = 1:length(o.buttonNames)
				% e.g. 'callback_btn_triggerPressed
				p.addParameter(sprintf('callback_btn_%sPressed',o.buttonNames{iB}),[],@(x) isa(x,'function_handle'));
				p.addParameter(sprintf('callback_btn_%sReleased',o.buttonNames{iB}),[],@(x) isa(x,'function_handle'));
			end
			p.addParameter('distToleranceForTrackerAgreement',c_convertValuesFromUnitToUnit(5,'mm',o.distUnit),@isscalar);
			p.addParameter('connectionTimeout',inf,@isscalar); % in s
			p.addParameter('assumeDroppedAfterTime',5,@isscalar); % in s, set to inf to assume never dropped
			p.addParameter('callback_connected',[],@(x) isa(x,'function_handle'));
			p.addParameter('callback_keepTryingToConnect',[],@(x) isa(x,'function_handle')); % called periodically if connectionTimeout==inf; if returns false, will abort connection attempt
			p.addParameter('callback_disconnected',[],@(x) isa(x,'function_handle'));
			p.addParameter('callback_trackingChange',[],@(x) isa(x,'function_handle')); % two inputs to callback: deviceStr, isTracking
			p.parse(varargin{:});

			% copy parsed input to object properties of the same name
			fieldNames = fieldnames(p.Results);
			for iF=1:length(fieldNames)
				if isprop(o,p.Parameters{iF})
					o.(fieldNames{iF}) = p.Results.(fieldNames{iF});
				end
			end

			c_say('%sConnecting...',o.printPrefix);
			
			o.nc = c_NetworkInterfacer(...
				'IP',p.Results.ip,...
				'port',p.Results.port,...
				'doDebug',o.doDebug,...
				'isServer',true,...
				'jtcpDoUseHelperClass',true,...
				'connectionTimeout',p.Results.connectionTimeout,...
				'callback_bufferOverflow',@o.onBufferOverflow,...
				'callback_keepTryingToConnect',p.Results.callback_keepTryingToConnect);
			
			if ~o.nc.isConnected
				c_sayDone('%sNot connected.',o.printPrefix);
				return;
			end
		
			c_sayDone('%sConnected.',o.printPrefix);
			
			if ~isempty(o.callback_connected)
				o.callback_connected();
			end
			
			o.parsedMsgTemplate = struct();
			for iB = 1:length(o.buttonNames)
				o.parsedMsgTemplate.(sprintf('btn_%s_isPressed',o.buttonNames{iB})) = false;
			end
			if o.doExpectQuaternions
				o.maxMsgLength = 2+2+(1+7*4)*4*o.maxNumTrackedDevices+2;
				for ID=1:o.maxNumTrackedDevices
					o.parsedMsgTemplate.(['XYZQuat_', o.trackedDeviceKeys{ID}]) = NaN(1,7);
				end
			else
				o.maxMsgLength = 2+2+(1+12*4)*o.maxNumTrackedDevices+2;
				for ID=1:o.maxNumTrackedDevices
					o.parsedMsgTemplate.(['transf_', o.trackedDeviceKeys{ID}]) = NaN(4,4);
				end
			end
			
			o.allTrackerKeys = o.trackedDeviceKeys(2:end); % fixed
			o.trackerKeys = o.trackedDeviceKeys(2:end); % may change later
			o.trackerTransforms = repmat(eye(4),1,1,o.maxNumTrackedDevices-1);
			
			o.partialMsgBuffer = c_RingBuffer(o.maxMsgLength,'bufferDimension',2);
			o.msgBuffer = c_RingBuffer(o.msgBufferLength,'dataIsStruct',true);
			
			if o.doPollAutomatically
				o.startPollTimer();
			end
		end

		%% destructor
		function delete(o)
			if o.doDebug
				c_saySingle('%sDeleting',o.printPrefix);
			end
			o.close();
		end
		%% misc
		function enableDebug(o)
			o.doDebug = true;
			o.nc.doDebug = true;
		end
		
		%% sampling

		function varargout = getMostRecent(o,whatToGet,numSamples)
			if nargin < 2
				whatToGet = 'XYZwrtTracker';
			end
			if nargin < 3
				numSamples = 1;
			end
			
			msgs = o.readFromBuffer(numSamples);
			
			varargout{:} = o.convertFromRawTo(whatToGet,msgs);
		end
			
		function varargout = convertFromRawTo(o,whatToGet,msgs)
			if iscell(whatToGet) && length(whatToGet)==3
				switch(whatToGet{1})
					case 'transf'
						varargout{1} = o.getTransfFromSpaceToSpace(whatToGet{2},whatToGet{3},msgs);
					case 'XYZ'
						varargout{1} = o.convertPtsFromSpaceToSpace([0 0 0],whatToGet{2},whatToGet{3},msgs);
					otherwise
						error('Invalid whatToGet: %s',c_toString(whatToGet));
				end
				return
			end
			switch(whatToGet)
				case 'XYZ'
					varargout{1} = o.convertPtsFromSpaceToSpace([0 0 0],'pointer','global',msgs);
				case 'XYZUncorrected'
					varargout{1} = o.convertPtsFromSpaceToSpace([0 0 0],'controller','global',msgs);
				case 'XYZwrtTracker' % note that this does not make use of o.trackerTransforms
					varargout{1} = o.convertPtsFromSpaceToSpace([0 0 0],'pointer','tracker',msgs);
				case 'XYZwrtTrackerUncorrected'
					varargout{1} = o.convertPtsFromSpaceToSpace([0 0 0],'controller','tracker',msgs);
				case 'XYZswrtTrackers' % note that this does not make use of o.trackerTransforms
					XYZs = o.convertPtsFromSpaceToSpace([0 0 0],'pointer','trackers',msgs);
					XYZs = permute(XYZs,[4 2 3 1]); % move per-tracker dimension from 4 to 1
					% so output is of size [numTrackers, 3, numMsgs]
					varargout{1} = XYZs;
					varargout{2} = o.trackerKeys; % also return labels for trackers
				case 'TrackerXYZ'
					varargout{1} = o.convertPtsFromSpaceToSpace([0 0 0],'tracker','global',msgs);
				case 'EulerAngles'
					transfs = o.getTransfFromSpaceToSpace('global','controller',msgs);
					varargout{1} = permute(c_calculateEulerAnglesFromRotationMatrix(transfs(1:3,1:3,:)),[3 2 1]);
				case 'TrackerEulerAngles'
					transfs = o.getTransfFromSpaceToSpace('global','tracker',msgs);
					varargout{1} = permute(c_calculateEulerAnglesFromRotationMatrix(transfs(1:3,1:3,:)),[3 2 1]);
				case 'transfControllerToTracker'
					varargout{1} = o.getTransfFromSpaceToSpace('controller','tracker',msgs);
				case 'transfControllerToGlobal'
					varargout{1} = o.getTransfFromSpaceToSpace('controller','global',msgs);
				case 'transfTrackerToGlobal'
					varargout{1} = o.getTransfFromSpaceToSpace('tracker','global',msgs);
				case 'transfTrackerToTracker'
					varargout{1} = eye(4);
				case 'RawMeasurement'
					varargout{1} = msgs;
				otherwise
					error('Invalid whatToGet: %s',whatToGet);
			end
		end
		
		function XYZ = getStable(o,varargin) 
			p = inputParser();
			p.addOptional('whatToGet','XYZwrtTracker',@(x) ischar(x) || iscellstr(x));
			p.addParameter('numSamplesForStability',20,@isscalar);
			p.addParameter('numSamplesToAverage',10,@isscalar); % from most recent sample at time of stability
			p.addParameter('distTolerance',1e-3,@isscalar); % in distUnit units
			p.addParameter('timeout',2,@isscalar); % in s, set to 0 to not block at all
			p.addParameter('doRequireFirstSampleToMatch',true,@islogical);
			p.addParameter('doClearBufferOnStart',false,@islogical);
			p.addParameter('doAudioFeedback',true,@islogical);
			p.addParameter('doHapticFeedback',true,@islogical);
			p.parse(varargin{:});
			s = p.Results;
	
			assert(s.numSamplesToAverage <= s.numSamplesForStability);
			doCheckForAgreement = false;
			
			if ischar(s.whatToGet)
				assert(ismember(s.whatToGet,{'XYZwrtTracker','XYZwrtTrackers','XYZwrtTrackerUncorrected','XYZ','XYZUncorrected'}));
				if strcmpi(s.whatToGet,'XYZwrtTrackers')
					doCheckForAgreement = true;
					s.whatToGet = 'XYZswrtTrackers';
				end
			else
				% whatToGet is in form {what,from,to}, e.g. {'XYZ','pointer','tracker'}
				assert(length(s.whatToGet)==3);
				assert(ismember(s.whatToGet{1},{'XYZ','XYZs'})); % not set up below to get stable transfs
				if strcmpi(s.whatToGet{3},'trackers')
					doCheckForAgreement = true;
					s.whatToGet{1} = 'XYZs';
				end
			end
			
			if s.doClearBufferOnStart
				% clear past history so that we know a set of stable samples were all recorded *after* the start of this function
				o.msgBuffer.clear();
			end
			
			if s.doRequireFirstSampleToMatch
				firstSample = [];
				% This will prevent cases where user presses trigger to sample while moving controller, expecting a sample at that point, but instead 
				% gets a "stable" sample without error when they stop the controller at the next target within a second
			end
			
			t = tic;
			dists = [];
			multiTrackerDists = [];
			while toc(t) < s.timeout
				% If at least numSamples not yet available (after clearing buffer), continue waiting until they are
% 				c_saySingle('Num messages in buffer: %d',o.msgBuffer.length);
				if s.doRequireFirstSampleToMatch && isempty(firstSample)
					if o.msgBuffer.length < 1
						pause(0.001);
						continue; % wait for more messages to show up
					else
						firstSample = o.getMostRecent(s.whatToGet,1);
						if doCheckForAgreement
							numTrackers = size(firstSample,1);
							for iT = 1:numTrackers
								firstSample(iT,:,:) = c_pts_applyTransform(permute(firstSample(iT,:,:),[3 2 1]),'quaternion',o.trackerTransforms(:,:,iT))';
							end
							firstSample = mean(firstSample,1);
						end
					end
				end

				if o.msgBuffer.length < s.numSamplesForStability
					pause(0.001);
					continue; % wait for more messages to show up
				end
				
				XYZs = o.getMostRecent(s.whatToGet,s.numSamplesForStability);
				
				if doCheckForAgreement
					numTrackers = size(XYZs,1);
					% apply o.trackerTransforms to convert coordinates from each tracker into a common coordinate space
					for iT = 1:numTrackers
						XYZs(iT,:,:) = c_pts_applyTransform(permute(XYZs(iT,:,:),[3 2 1]),'quaternion',o.trackerTransforms(:,:,iT))';
					end
					meanXYZs = mean(XYZs,1); % average across trackers
					multiTrackerDists = c_norm(bsxfun(@minus,XYZs,meanXYZs),2,2);
					if any(multiTrackerDists > s.distTolerance*2)
						if o.doDebug
							c_say('Disagreement between trackers:');
							c_saySingle('Min disagreement: %s %s',c_toString(c_convertValuesFromUnitToUnit(min(multiTrackerDists(:)),o.distUnit,'mm')),'mm');
							c_saySingle('Max disagreement: %s %s',c_toString(c_convertValuesFromUnitToUnit(max(multiTrackerDists(:)),o.distUnit,'mm')),'mm');
							c_sayDone();
						end
						pause(0.0001);
						continue;
					end
					multiTrackerDists = []; % clear to show that multiTrackerDists were not the reason for failure below
					XYZs = meanXYZs;
				end
				
				meanXYZ = mean(XYZs,3);
				dists = c_norm(bsxfun(@minus,XYZs,meanXYZ),2,2);
				if all(dists <= s.distTolerance)
					% samples are "stable"
					if o.doDebug
						c_say('%sMeasurement is stable, based on %d samples',o.printPrefix,s.numSamplesForStability);
						c_saySingle('Mean sample: %s %s',	    c_toString(c_convertValuesFromUnitToUnit(	meanXYZ,		o.distUnit,'mm')),'mm');
						c_saySingle('Most recent: %s %s',		c_toString(c_convertValuesFromUnitToUnit(	XYZs(:,:,end),	o.distUnit,'mm')),'mm');
						c_saySingle('Max dist from mean: %.3g %s',				c_convertValuesFromUnitToUnit(	max(dists),	o.distUnit,'mm'),'mm');
						c_saySingle('Standard deviation of samples: %.3g %s',	c_convertValuesFromUnitToUnit(	std(dists),	o.distUnit,'mm'),'mm');
						c_sayDone();
					end
					
					if s.doRequireFirstSampleToMatch
						dist = c_norm(meanXYZ - firstSample,2,2);
						firstSampleTolerance = s.distTolerance*3;
						if dist > firstSampleTolerance
							% measurement stable, but does not match measurement at start of sampling period
							% (indicating a large change from when "intended" sample was triggered)
							if s.doHapticFeedback || s.doAudioFeedback
								feedbackArgs = {};
								if s.doHapticFeedback
									feedbackArgs = [feedbackArgs,'hapticStrength',1];
								end
								if s.doAudioFeedback
									feedbackArgs = [feedbackArgs, 'audioTone','warning'];
								end
								o.sendFeedback(feedbackArgs{:});
							end
							warning('%sObtained stable sample, but changed drastically before stabilizing (%.3g %s > %.3g), so rejecting.',...
								o.printPrefix,c_convertValuesFromUnitToUnit(dist,	o.distUnit,'mm'),'mm',c_convertValuesFromUnitToUnit(firstSampleTolerance,o.distUnit,'mm'));
							XYZ = [];
							return;
						end
					end
					
					XYZ = mean(XYZs(:,:,(end-s.numSamplesToAverage):end),3);
					if s.doHapticFeedback || s.doAudioFeedback
						feedbackArgs = {};
						if s.doHapticFeedback
							feedbackArgs = [feedbackArgs,'hapticStrength',0.5];
						end
						if s.doAudioFeedback
							feedbackArgs = [feedbackArgs, 'audioTone','success'];
						end
						o.sendFeedback(feedbackArgs{:});
					end
					return;
				end
				pause(0.001);
			end
			
			% if reached here, then we timed out
			if s.doHapticFeedback || s.doAudioFeedback
				feedbackArgs = {};
				if s.doHapticFeedback
					feedbackArgs = [feedbackArgs,'hapticStrength',1];
				end
				if s.doAudioFeedback
					feedbackArgs = [feedbackArgs, 'audioTone','warning'];
				end
				o.sendFeedback(feedbackArgs{:});
			end
			if ~isempty(multiTrackerDists)
				warning([...
					'%sDid not obtain agreement between trackers:\n',...
					'\tMax disagreement: %s %s\n',...
					'\tPer-tracker mean disagreement: %s %s'],...
					o.printPrefix,...
					c_toString(c_convertValuesFromUnitToUnit(max(multiTrackerDists(:)),o.distUnit,'mm')),'mm',...
					c_toString(c_convertValuesFromUnitToUnit(mean(multiTrackerDists,3),o.distUnit,'mm'))','mm');
			elseif ~isempty(dists)
				warning('%sDid not obtain stable sample within %.3g s. Max dist: %.3g %s',...
					o.printPrefix,s.timeout,c_convertValuesFromUnitToUnit(max(dists),o.distUnit,'mm'),'mm');
			else
				warning('%sDid not obtain %d samples within %.3g s to characterize stability (%d)',...
					o.printPrefix, s.numSamplesForStability,s.timeout,o.msgBuffer.length);
			end
			XYZ = [];
		end
		
		function set.XYZOffset(o,offset)
			if ~isempty(offset)
				assert(isvector(offset));
				assert(length(offset)==3);
			end
			o.XYZOffset = offset;
		end
		
		function set.trackerKeys(o,newTrackerKeys)
			assert(all(ismember(newTrackerKeys,o.trackedDeviceKeys)));
			o.trackerKeys = newTrackerKeys;
			o.resetTrackerTransforms();
		end
		
		function set.trackerTransforms(o,newTransforms)
			assert(isequal(c_size(newTransforms,[1 2 3]),[4 4 length(o.trackerKeys)]));
			o.trackerTransforms_ = newTransforms;
		end
		function transfs = get.trackerTransforms(o)
			transfs = o.trackerTransforms_;
		end
		
		function resetTrackerTransforms(o)
			if o.doDebug
				c_saySingle('%Resetting tracker transforms',o.printPrefix);
			end
			o.trackerTransforms = repmat(eye(4),1,1,length(o.trackerKeys));
		end
		
		function val = get.hasTrackerTransforms(o)
			val = ~isequal(o.trackerTransforms,repmat(eye(4),1,1,o.maxNumTrackedDevices-1));
		end
		
		function transf = getTransfFromSpaceToSpace(o,fromSpace,toSpace,msgs)
			transf = eye(4,4);
			
			if nargin < 4
				msgs = o.readFromBuffer(1);
			end
			
			if isempty(msgs)
				return;
			end
			
			if isequal(fromSpace,toSpace)
				return;
			end
			
			if length(msgs) > 1
				% get a transform for each message
				transfs = nan(4,4,length(msgs));
				for iM = 1:length(msgs)
					tmp = o.getTransfFromSpaceToSpace(fromSpace, toSpace, msgs(iM));
					if size(tmp,4) > size(transfs,4)
						transfs = cat(4,transfs,nan([c_size(transfs,1:3), size(tmp,4)-size(transfs,4)]));
					end
					transfs(:,:,iM,:) = tmp;
				end
				transf = transfs;
				return;
			end
			
			msg = msgs;
			
			%c_saySingle('Msg: %s',c_toString(msg));
			
			switch(fromSpace)
				case 'global'
					switch(toSpace)
						case 'controller'
							transf = o.getTransfFromSpaceToSpace('controller','global',msg);
							if ~all(isnan(transf(:)))
								transf = pinv(transf);
							end
						case o.allTrackerKeys
							transf = o.getTransfFromSpaceToSpace(toSpace,'global',msg);
							if ~all(isnan(transf(:)))
								transf = pinv(transf);
							end
						case 'trackers'
							transf = o.getTransfFromSpaceToSpace(toSpace,'global',msg);		
							for iT = 1:size(transf,4)
								if all(~isnan(reshape(transf(:,:,:,iT),1,[])))
									transf(:,:,:,iT) = pinv(transf(:,:,:,iT));
								end
							end
						case 'pointer'
							transf = o.getTransfFromSpaceToSpace('global','controller',msg);
							transf = o.getTransfFromSpaceToSpace('controller','pointer',msg)*transf;
						otherwise
							error('can''t convert from %s to %s',fromSpace,toSpace);
					end
				case 'controller'
					switch(toSpace)
						case 'pointer'
							if ~isempty(o.XYZOffset)
								transf(1:3,4) = -1*o.XYZOffset;
							else
								% no change if offset is not specified
							end
						case o.allTrackerKeys
							transf = o.getTransfFromSpaceToSpace('controller','global',msg);
							transf = o.getTransfFromSpaceToSpace('global',toSpace,msg)*transf;
						case 'global'
							if o.doExpectQuaternions
								transf = o.getTransfForQuat(msg.XYZQuat_controller);
							else
								transf = msg.transf_controller;
							end
						otherwise
							error('Can''t convert from %s to %s',fromSpace,toSpace);
					end
				case 'pointer'
					switch(toSpace)
						case 'controller'
							if ~isempty(o.XYZOffset)
								transf(1:3,4) = o.XYZOffset;
							else
								% no change if offset is not specified
							end
						case 'global'
							transf = o.getTransfFromSpaceToSpace('global','pointer',msg);
							if ~all(isnan(transf(:)))
								transf = pinv(transf);
							end
						case o.allTrackerKeys
							transf = o.getTransfFromSpaceToSpace('pointer','controller',msg);
							transf = o.getTransfFromSpaceToSpace('controller','global',msg)*transf;
							transf = o.getTransfFromSpaceToSpace('global',toSpace,msg)*transf;
						case 'trackers'
							transf = o.getTransfFromSpaceToSpace('pointer','controller',msg);
							transf = o.getTransfFromSpaceToSpace('controller','global',msg)*transf;
							transf = c_mat_applyFnToSlices(@(slc) slc*transf,...
								o.getTransfFromSpaceToSpace('global','trackers',msg),...
								1:2);
						otherwise
							error('Can''t convert from %s to %s',fromSpace,toSpace);
					end
				case o.allTrackerKeys
					switch(toSpace)
						case 'global'
							if o.doExpectQuaternions
								transf = o.getTransfForQuat(msg.(['XYZQuat_' fromSpace]));
							else
								transf = msg.(['transf_' fromSpace]);
							end
						case {'controller','pointer'}
							transf = o.getTransfFromSpaceToSpace(toSpace,fromSpace,msg);
							if ~all(isnan(transf(:)))
								transf = pinv(transf);
							end
						case o.allTrackerKeys
							transf = o.getTransfFromSpaceToSpace(fromSpace,'global',msg);
							transf = o.getTransfFromSpaceToSpace('global',toSpace,msg)*transf;
						otherwise
							error('can''t convert from %s to %s',fromSpace,toSpace);
					end
				case 'trackers'
					switch(toSpace)
						case 'global'
							transf = nan(4,4,1,length(o.trackerKeys));
							for iT = 1:length(o.trackerKeys)
								transf(:,:,1,iT) = o.getTransfFromSpaceToSpace(o.trackerKeys{iT},'global');
							end
						otherwise
							error('can''t convert from %s to %s',fromSpace,toSpace);
					end	
				otherwise
					error('Can''t convert from %s to %s',fromSpace,toSpace);
			end
		end
		
		function XYZ = convertPtsFromSpaceToSpace(o,XYZ,varargin)
			transfs = o.getTransfFromSpaceToSpace(varargin{:});
			XYZ = repmat(XYZ,1,1,size(transfs,3),size(transfs,4));
			for iT = 1:size(transfs,4)
				for iM = 1:size(transfs,3)
					XYZ(:,:,iM,iT) = c_pts_applyTransform(XYZ(:,:,iM,iT),'quaternion',transfs(:,:,iM,iT));
				end
			end
		end
		
		function transf = getTransfForQuat(o,Quat)
			assert(isvector(Quat) && (length(Quat)==4 || length(Quat)==7));
			
			transf = eye(4);
			if all(isnan(Quat))
				transf = nan(4);
			elseif length(Quat) == 4
				% assume input is rotation only
				transf(1:3,1:3) = c_calculateRotationMatrixFromQuaternionVector(Quat).';
			else
				% assume input is rotation and offset
				transf(1:3,1:3) = c_calculateRotationMatrixFromQuaternionVector(Quat(4:7)).';
				transf(1:3,4) = Quat(1:3);
			end
		end
		
		%% networking 
		function iscon = isConnected(o)
            try
                iscon = ~isempty(o.nc) && o.nc.isConnected();
                if o.doDebug
                    c_saySingle('%sisConnected: %d',o.printPrefix,iscon);
                end
            catch
                iscon = false; % catch case where called from within destructor, which seems to cause problems...
            end
		end

		function onBufferOverflow(o)
			warning('Buffer overflow detected. Discarding data to try to catch up.');
			o.nc.clearReadBuffer();
			o.partialMsgBuffer.clear(); % clear any previously buffered partial messages
		end
		
		function close(o)
			didClose = false;
			if ~isempty(o.tmr)
				o.clearTimers();
				didClose = true;
				pause(0.5); % wait for timer(s) to finish
			end
			
            if ~isempty(o.nc)
                if o.doDebug
                    c_say('%sClosing network client',o.printPrefix);
                end
                if o.isConnected()
                    didClose = true;
                end
                o.nc.close();
                o.nc = [];
                if o.doDebug
                    c_sayDone('%sDone closing network client',o.printPrefix);
                end
            end
			
			if ~isempty(o.callback_disconnected)
				if o.doDebug
					c_say('%sRunning callback_disconnected',o.printPrefix);
				end
				o.callback_disconnected();
				if o.doDebug
					c_sayDone('%sDone running callback_disconnected',o.printPrefix);
				end
			end
			
			if didClose
				c_saySingle('%sClosed',o.printPrefix);
			end
		end
		
		function numRead = tryReadToBuffer(o)
			maxNumRead = 100;
			
			iM = 1;
			while iM <= maxNumRead
				if ~o.isConnected()
					break;
				end
				newMsg = o.tryRead();
				if isempty(newMsg)
					break;
				end
				o.msgBuffer.pushBack(newMsg);
				iM = iM+1;
			end
			numRead = iM-1;
		end
		
		function msgs = readFromBuffer(o,numMsgs)
			numMsgs = min(numMsgs,o.msgBuffer.numValid);
			msgs = o.msgBuffer.peekBack(numMsgs);
		end
		
		function msg = tryRead(o)
			
			state = 'lookingForStart';
			% read until finding magic bytes or buffer is empty
			msg = [];
			endBytes = [0,0];
   			numEndBytes = length(endBytes);
   			numStartBytes = 2;       

			try
				while true
					if o.doDebug
						c_saySingle('%stryRead: state: %s',o.printPrefix,state);
					end
					switch(state)
						case 'lookingForStart'
							if o.partialMsgBuffer.numValid<numStartBytes
								% not enough bytes in buffer for start bytes
								byteRead = o.nc.tryRead('numBytes',numStartBytes);
								if isempty(byteRead)
									return; % reached end of buffer without finding start of message
								end
								o.partialMsgBuffer.pushBack(byteRead);
							end
                            
                            % if reached here, there are bytes in partialMsgBuffer to check
							candidateBytes = typecast(int8(o.partialMsgBuffer.peekFront(numStartBytes)),'uint8');
                            
							if ~isequal(candidateBytes(1),hex2dec('FF'))
								c_saySingle('Invalid header (%d != %d)',hex2dec('FF'),candidateBytes(1));
								o.partialMsgBuffer.popFront(1);
								continue;
							end
							
							numTrackedDevices = double(candidateBytes(2) - hex2dec('54'));
							if ~(numTrackedDevices > 0 && numTrackedDevices <= o.maxNumTrackedDevices)
								c_saySingle('Invalid header (unexpected number of poses: %d)',numTrackedDevices);
								o.partialMsgBuffer.popFront(1);
								continue;
							end
							
							% found start

							if o.doExpectQuaternions
								numBytesInMsg = numStartBytes + 1*2 + (1+7*4)*numTrackedDevices + numEndBytes;
							else
								numBytesInMsg = numStartBytes + 1*2 + (1+12*4)*numTrackedDevices + numEndBytes;
							end

							state = 'readingMessage';
							
						case 'readingMessage'
							if o.partialMsgBuffer.numValid < numBytesInMsg
								bytesRead = o.nc.tryRead('maxNumBytes',numBytesInMsg-o.partialMsgBuffer.numValid);
								if isempty(bytesRead)
									return; % reached end of buffer without finding entire message
								end
								o.partialMsgBuffer.pushBack(bytesRead);
								continue
							else
								% reached end of message
								state = 'readCompleteMessage';
								break;
							end
						otherwise
							error('Invalid state');
					end
				end
			catch E
				warning('Exception during tryRead(). Returning empty msg.');
				msg = [];
				return;
			end
			
			% if reaching here, should have read a complete message
			assert(strcmp(state,'readCompleteMessage'));
			
			if o.doDebug
				c_saySingle('%sRead complete message: %s',o.printPrefix,c_toString(o.partialMsgBuffer.peekFront(numBytesInMsg)));
			end
			
			% confirm that end bytes are as expected
			candidateBytes = o.partialMsgBuffer.peekBack(numEndBytes);
			if ~isequal(candidateBytes,endBytes)
				warning('Ending bytes (%s) do not match as expected, dropping message',c_toString(candidateBytes));
				msg = [];
				return;
			end
			
			% convert raw message to useful format
			parsedMsg = o.parsedMsgTemplate;
			msg = o.partialMsgBuffer.peekFront(numBytesInMsg);
			
			% strip out start and end bytes
			msg = msg(numStartBytes+1:end-numEndBytes);
			
			% first two bytes are buttonStates
			buttonStates = typecast(int8(msg(1:2)),'uint16');
			
			for iB = 1:length(o.buttonNames)
				parsedMsg.(sprintf('btn_%s_isPressed',o.buttonNames{iB})) = bitand(buttonStates,bitshift(1,o.buttonStateNums(iB)));
			end
			
			doDisconnect = bitand(buttonStates,bitshift(1,o.closeConnectionNum));
			
			if o.doExpectQuaternions
				% next bytes are orientation info for controller and tracker, in [ID,X,Y,Z,Qw,Qx,Qy,Qz] format
				for j = 1:numTrackedDevices
					XYZQuat = nan(1,7);
					ID = typecast(int8(msg(2+(j-1)*(1+4*7)+1)),'uint8') + 1; % note plus one at end to convert from 0-indexing to 1-indexing
					assert(ID > 0 && ID <= length(o.trackedDeviceKeys),'Invalid pose ID: %d',ID);
					for i = 1:7
						XYZQuat(i) = typecast(int8(msg(2+(i-1)*4+(j-1)*(1+4*7)+(1:4)+1)),'single');
					end

					if o.doRemapAxes
						remapOrder = [1 3 2 4 5 7 6];
						XYZQuat = XYZQuat(remapOrder);
					end

					if isequal(XYZQuat,[0 0 0 1 0 0 0]) % indicates invalid tracking
						XYZQuat(:) = NaN;
					end

					parsedMsg.(['XYZQuat_' o.trackedDeviceKeys{ID}]) = XYZQuat;
				end
			else
				% next bytes are orientation info for controller and tracker, in ID+3x4 transform matrix format
				for j = 1:numTrackedDevices
					transf = eye(4);
					% note that last row of transf will remain [0 0 0 1]
					ID = typecast(int8(msg(2+(j-1)*(1+4*12)+1)),'uint8') + 1; % note plus one at end to convert from 0-indexing to 1-indexing
					assert(ID > 0 && ID <= length(o.trackedDeviceKeys),'Invalid pose ID: %d',ID);
					i = 0;
					for r = 1:3
						for c = 1:4
							i = i + 1;
							transf(r,c) = typecast(int8(msg(2+(i-1)*4+(j-1)*(1+4*12)+(1:4)+1)),'single');
						end
					end
					
					if isequal(transf,[0 0 0 0; 0 0 0 0; 0 0 0 0; 0 0 0 1]) % indicates invalid tracking
						transf(:) = NaN;
					end
					
					parsedMsg.(['transf_' o.trackedDeviceKeys{ID}]) = transf;
				end		
			end
			
			msg = parsedMsg;
			
			msg.time = datetime();
			
			%c_saySingle('ControllerXYZ: %30s \t TrackerXYZ: %30s',c_toString(msg.XYZQuat_controller(1:3)), c_toString(msg.XYZQuat_tracker(1:3)));
			
			o.partialMsgBuffer.clear();
			
			% button event callbacks
			if ~isempty(o.prevMsg)
				for iB = 1:length(o.buttonNames)
					stateField = sprintf('btn_%s_isPressed',o.buttonNames{iB});
					callbackPressedField = sprintf('callback_btn_%sPressed',o.buttonNames{iB});
					callbackReleasedField = sprintf('callback_btn_%sReleased',o.buttonNames{iB});
					if ~o.prevMsg.(stateField) && msg.(stateField) && ~isempty(o.(callbackPressedField))
						o.(callbackPressedField)(msg);
					elseif o.prevMsg.(stateField) && ~msg.(stateField) && ~isempty(o.(callbackReleasedField))
						o.(callbackReleasedField)(msg);
					end
				end
			end

			% check for loss of tracking by looking for NaNs
			for dev = o.trackedDeviceKeys
				dev = dev{1};
				if o.doExpectQuaternions
					field = ['XYZQuat_' dev];
				else
					field = ['transf_' dev];
				end
				if all(isnan(msg.(field)(:))) && ~isempty(o.prevMsg) && ~all(isnan(o.prevMsg.(field)(:)))
					if o.doDebug
						c_saySingle('%s%s tracking lost',o.printPrefix,dev);
					end
					if ~isempty(o.callback_trackingChange)
						o.callback_trackingChange(dev,false);
					end
				elseif (isempty(o.prevMsg) || all(isnan(o.prevMsg.(field)(:)))) && ~all(isnan(msg.(field)(:)))
					if o.doDebug
						c_saySingle('%s%s tracking began',o.printPrefix,dev);
					end
					if ~isempty(o.callback_trackingChange)
						o.callback_trackingChange(dev,true);
					end
				end
			end
			
			o.prevMsg = msg;
			
			if doDisconnect
				if o.doDebug
					c_say('%sReceived disconnect message, closing',o.printPrefix);
				end
				o.close();
				if o.doDebug
					c_sayDone('%sDone closing after receiving disconnect',o.printPrefix);
				end
			end
		end
		
	
		%% timer-related methods
		function startPollTimer(o)
			o.clearTimers();
			o.tmr = timer(...
				'BusyMode','drop',...
				'ExecutionMode','fixedSpacing',...
				'Name','VRDigitizerPollingTimer',...
				'Period',o.pollPeriod,...
				'TimerFcn',@(h,e)o.pollInputCallback);
			start(o.tmr);
		end

		function clearTimers(o)
			if o.doDebug
				c_say('%sClearing timers',o.printPrefix);
			end
			tmp = timerfindall('Name','VRDigitizerPollingTimer');
			if ~isempty(tmp)
				if o.doDebug
					c_saySingleMultiline('%sStopping timer(s) %s',o.printPrefix,c_toString(tmp));
				end
				stop(tmp);
				delete(tmp);
			end
			o.tmr = [];
			pause(o.pollPeriod*2);
			if o.doDebug
				c_sayDone('%sDone clearing timers',o.printPrefix);
			end
		end

		function pausePolling(o)
			if o.doDebug
				c_saySingle('%sPausing polling',o.printPrefix);
			end
			assert(~isempty(o.tmr));
			o.pollerIsPaused = true;
		end
		
		function resumePolling(o)
			if o.doDebug
				c_saySingle('%Resuming polling',o.printPrefix);
			end
			assert(~isempty(o.tmr));
			o.nc.clearReadBuffer(); % clear buffer to prevent any buffer overflow warnings from being paused for extended time
			o.pollerIsPaused = false;
		end
		
		function pollInputCallback(o)
			% to be called periodically, e.g. by a timer in the "background"
			if o.pollerIsPaused
				return;
			end
			
			if o.mutex_buffer
				c_saySingle('%sMutex collision, can''t run timer',o.printPrefix);
				return;
			end
			o.mutex_timerCallbackRunning = true;
			if o.doDebug
				c_say('%sPoller: trying read to buffer',o.printPrefix);
			end
			numRead = o.tryReadToBuffer();
			if numRead > 0
				o.timeOfLastMessage = tic;
			elseif ~isempty(o.timeOfLastMessage)
				timeSinceLast = toc(o.timeOfLastMessage);
				if timeSinceLast > o.assumeDroppedAfterTime
					%if o.doDebug
						c_saySingle('%sMore than %.3g s without a message. Assuming connection dropped.',o.printPrefix,o.assumeDroppedAfterTime);
					%end
					o.close();
				end
			end
			if o.doDebug
				c_sayDone('%sPoller: done trying read to buffer, read %d msgs',o.printPrefix,numRead);
			end
			o.mutex_timerCallbackRunning = false;
		end
		
		%% feedback methods
		function sendFeedback(o,varargin)
			p = inputParser();
			p.addParameter('hapticStrength',0,@(x) isscalar(x) && x >= 0 && x<= 1);
			p.addParameter('audioTone','none',@ischar);
			p.parse(varargin{:});
			s = p.Results;
			
			if s.hapticStrength == 0 && strcmpi(s.audioTone,'none')
				% do nothing
				return;
			end
			
			bitsForAudio = 2;
			bitsForHaptic = 6;
			assert(bitsForAudio+bitsForHaptic==8);
			
			toSend = uint8(0);
			
			switch(s.audioTone)
				case 'none'
					audioVal = 0;
				case 'success'
					audioVal = 1;
				case 'warning'
					audioVal = 2;
				case 'error'
					audioVal = 3;
				otherwise
					error('Invalid audioTone: %s',s.audioTone);
			end
			
			assert(audioVal >= 0 && audioVal < 2^bitsForAudio);
			
			toSend = bitor(toSend, uint8(audioVal));
			
			if s.hapticStrength > 0
				% convert from [0,1] range to bits 7-12 of a 16 bit haptic pulse microseconds duration
				
				hapticLowestBit = 7;
				hapticHighestBit = 12;
				assert(hapticHighestBit - hapticLowestBit + 1 == bitsForHaptic);
				maxStrength = 2^hapticHighestBit-1;
				hapticBitMask = bitxor(uint16(2^hapticHighestBit-1),uint16(2^(hapticLowestBit-1)-1));
				
				hapticVal = uint16(round(s.hapticStrength*maxStrength));
				hapticVal = bitand(hapticVal, hapticBitMask);
				hapticVal = bitshift(hapticVal,-(hapticLowestBit-1)+bitsForAudio);
				
				assert(hapticVal < 2^8);
				
				toSend = bitor(toSend, uint8(hapticVal));
			end
			
			if o.doDebug
				c_saySingle('%sSending feedback with byte 0b%s (%d)',o.printPrefix,dec2bin(toSend),toSend);
			end
				
			assert(o.nc.isConnected);
			o.nc.sendBytes(typecast(toSend,'int8'));
		end
		
	end
	
	
	%% class static methods
	methods(Static)
		function addDependencies()
			persistent pathModified;
			if isempty(pathModified)
				mfilepath=fileparts(which(mfilename));
				addpath(fullfile(mfilepath,'./Common'));
				addpath(fullfile(mfilepath,'./Common/Network'));
				addpath(fullfile(mfilepath,'./Common/MeshFunctions'));
				addpath(fullfile(mfilepath,'./Common/ThirdParty/GetFullPath'));
				c_NetworkInterfacer.addDependencies();
				pathModified = true;
			end
		end
		
		function plotRawRealtime(varargin)
			VRDigitizerInterfacer.addDependencies();
			p = inputParser();
			p.addParameter('maxNumSamples',200,@isscalar);
			p.addParameter('sampleFractions',[1 0.5 0.1 0.05],@isvector);
			p.addParameter('whatToPlot',...
...				{'XYZUncorrected'},...
... 			{'XYZUncorrected','TrackerXYZ'},...
				{'XYZUncorrected','EulerAngles'},...
...				{'TrackerXYZ','TrackerEulerAngles'},...
...				{'TrackerXYZ','TrackerEulerAngles'},...
				@iscellstr);
			p.parse(varargin{:});
			s = p.Results;
			
			d = VRDigitizerInterfacer(...
				'doPollAutomatically',true...
				);
			
			figure('name','Raw digitizer plot',...
				'CloseRequestFcn',@(h,e)  c_void({@d.close, @closereq},[])...
				);
			
			assert(all(s.sampleFractions <= 1));
			sampleSubsetLengths = floor(s.sampleFractions*s.maxNumSamples);
			
			pHs = gobjects();
			pTHs = gobjects();
			doFirstTimeInit = true;
			
			while d.isConnected()
				msgs = d.getMostRecent('RawMeasurement',s.maxNumSamples);
				vals = cell(1,length(s.whatToPlot));
				for iW = 1:length(s.whatToPlot)
					vals{iW} = d.convertFromRawTo(s.whatToPlot{iW},msgs);
					
					if ~isempty(strfind(s.whatToPlot{iW},'XYZ'))
						% convert to mm
						vals{iW} = c_convertValuesFromUnitToUnit(vals{iW},d.distUnit,'mm');
						% add norm as fourth value
						vals{iW}(:,4,:) = c_norm(vals{iW}(:,1:3,:),2,2);
					elseif ~isempty(strfind(s.whatToPlot{iW},'Angles'))
						% convert from radians to degrees for plotting
						vals{iW} = rad2deg(vals{iW});
					end
				end
				
				numRows = sum(cellfun(@(x) size(x,2),vals));
				numCols = length(s.sampleFractions);
				iR = 1;
				x = 1:s.maxNumSamples;
				for iW = 1:length(s.whatToPlot)
					for iN = 1:size(vals{iW},2)
						for iC = 1:numCols
							if doFirstTimeInit
								pHs(iR,iC) = c_subplot(numRows,numCols,iR,iC);
								set(pHs(iR,iC),'NextPlot','replacechildren');
								pTHs(iR,iC) = title('waiting...');
								if iC == 1
									ylabel(sprintf('%s(%d)',s.whatToPlot{iW},iN));
								end
							end
							if length(msgs) < sampleSubsetLengths(iC)
								continue; % not enough data yet
							end
							indices = s.maxNumSamples - (sampleSubsetLengths(iC)-1:-1:0) - (s.maxNumSamples - length(msgs));
							plot(pHs(iR,iC),x(indices), squeeze(vals{iW}(:,iN,indices)));
							pTHs(iR,iC).String = [...
								sprintf('Mean: %6.3g\n',mean(vals{iW}(:,iN,indices))),...
								sprintf('P2P: %6.3g    ',diff(extrema(vals{iW}(:,iN,indices)))),...
								sprintf('Std: %6.3g',std(vals{iW}(:,iN,indices))),...
								];
						end
						iR = iR + 1;
					end
				end
					
				doFirstTimeInit = false;
				
				pause(0.05);
			end
		end
		
		function test()
			c_sayResetLevel();
			c_say('Running VRDigitizerInterfacer test');
			VRDigitizerInterfacer.addDependencies();
			d = VRDigitizerInterfacer('doDebug',true,'pollPeriod',0.001);
			
			hf = figure('name','VRDigitizerInterfacer test');
			ha = axes('parent',hf);
			view(3);
			axis(ha,'equal');
			xlim([-1 1]*2);
			ylim([-1 1]*2);
			zlim([-1 1]*2);
			hold on;
			h = [];
			N = 0;
			maxNumToPlot = 100;
			plotSubsampling = 1;
			while true
				numRead = d.tryReadToBuffer();
				if numRead > 0
					msgs = d.readFromBuffer(maxNumToPlot*plotSubsampling);
					for i = 1:numRead
						%c_saySingle('%s',c_toString(msgs(end-numRead+i,:)));  % print new messages
					end
					if ~isempty(h)
						delete(h);
					end
					if 0
						XYZs = msgs;
					else
						XYZs = cell2mat(arrayfun(@(msg) msg.transf_controller(1:3,4),msgs,'UniformOutput',false)')';
					end
						
					h = c_plot_scatter3(XYZs(size(XYZs,1):-plotSubsampling:1,:),...
						'ptSizes',0.05,...
						'axis',ha);
					drawnow();
				end
			end
			c_sayDone();
		end
	end
	
end