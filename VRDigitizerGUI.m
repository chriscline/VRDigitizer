function VRDigitizerGUI(varargin)
	
	%% add dependencies
	persistent pathModified;
	if isempty(pathModified)
		mfilepath=fileparts(which(mfilename));
		addpath(fullfile(mfilepath,'./Common'));
		addpath(fullfile(mfilepath,'./Common/MeshFunctions'));
		addpath(fullfile(mfilepath,'./Common/EEGAnalysisCode'));
		addpath(fullfile(mfilepath,'./Common/ThirdParty/findjobj'));
		addpath(fullfile(mfilepath,'./Common/GUI'));
		c_GUI_initializeGUILayoutToolbox();
		if ~exist('fmincon','file')
			addpath(fullfile(mfilepath,'./Common/ThirdParty/psomatlab')); % only needed if don't have optimization toolbox license
		end
		VRDigitizerInterfacer.addDependencies();
		pathModified = true;
	end
	
	%% inputs / settings
	p = inputParser();
	p.addParameter('basePath',fileparts(which(mfilename)),@ischar);
	p.addParameter('persistentSettingsPath','./VRDigitizerGUI_SavedSettings.mat',@ischar); % only path that is always relative to mfilename location
	p.addParameter('doPromptIfClosingUnsaved',true,@islogical);
	p.addParameter('distUnit',1e-3,@isscalar);
	p.addParameter('windowPosition',[],@isvector);
	p.addParameter('doSpeak',ispc,@islogical);
	p.addParameter('doSpeakVerbose',ispc,@islogical);
	p.addParameter('speechLexiconPath','./Resources/DigitizerSpeechLexicon.pls',@ischar);
	% montage
	p.addParameter('templateMontagePath','./Resources/Biosemi128.pos',@ischar); % path to default (non-measured) montage
	p.addParameter('templateMontage',[],@(x) isa(x,'c_DigitizedMontage'));
	p.addParameter('measuredMontagePath',[],@ischar); % path to measured montage
	p.addParameter('measuredMontage',[],@(x) isa(x,'c_DigitizedMontage'));
	% measurement settings
	p.addParameter('measurementTransform',[],@ismatrix);
	p.addParameter('doSupportMultipleTrackers',true,@islogical); % requires relaunch if changed
	p.addParameter('trackedDeviceKeys',{'controller','controller2','tracker','tracker2','hmd'},@iscellstr); % should match that set in VRDigitizerInterfacer
	p.addParameter('doSampleRelativeTo_controller2',false,@islogical);
	p.addParameter('doSampleRelativeTo_tracker',false,@islogical);
	p.addParameter('doSampleRelativeTo_tracker2',false,@islogical);
	p.addParameter('doSampleRelativeTo_hmd',false,@islogical);
	p.addParameter('doRequireStableSample',true,@islogical);
	p.addParameter('stableSampleDistThreshold',1,@isscalar);
	% VR connection
	p.addParameter('doConnectOnStartup',true,@islogical);
	p.addParameter('doLaunchHelperExeAutomatically',true,@islogical);
	p.addParameter('helperExePath','./python/build/exe.win32-2.7/VRDigitizer_helper.exe',@ischar);
	p.addParameter('vr_ip','127.0.0.1',@ischar);
	p.addParameter('vr_port',3947,@isscalar);
	p.addParameter('vr_distUnit','m',@(x) ischar(x) || isscalar(x));
	% calibration
	p.addParameter('digitizerCalibrationPath','',@ischar); % path to digitizer calibration parameters
	p.addParameter('digitizerCalibration',[],@isstruct);
	% visualization
	p.addParameter('view',[-135 20]);
	% visualization - montages
	p.addParameter('doPlotElectrodes',true,@islogical);
	p.addParameter('doPlotFiducials',true,@islogical);
	p.addParameter('doPlotShapePts',true,@islogical);
	p.addParameter('doPlotTemplateElectrodes',true,@islogical);
	p.addParameter('doPlotTemplateFiducials',false,@islogical);
	p.addParameter('doPlotTemplateShapePts',false,@islogical);
	p.addParameter('doLabelElectrodes',true,@islogical);
	p.addParameter('doLabelFiducials',false,@islogical);
	p.addParameter('doLabelTemplateElectrodes',true,@islogical);
	p.addParameter('doLabelTemplateFiducials',false,@islogical);
	% visualization - head mesh
	p.addParameter('meshPath','./Resources/ICBM152_Skin.stl',@ischar); % path to scalp mesh
	p.addParameter('doPlotHeadMesh',true,@islogical);
	p.addParameter('mesh',[],@c_mesh_isValid);
	p.addParameter('meshDistUnit',1e-3,@isscalar);
	p.addParameter('meshFaceColor',[255 220 177]/255,@isvector);
	p.addParameter('meshFaceAlpha',0.5,@isscalar);
	% visualization - tracked devices
	p.addParameter('doPlotControllerMesh',true,@islogical);
	p.addParameter('doPlotTrackerMesh',true,@islogical);
	p.addParameter('doPlotHmdMesh',false,@islogical);
	p.addParameter('doPlotControllerEndpoint',true,@islogical);
	p.addParameter('controllerMeshPath','./Resources/Vive_Controller.stl',@ischar);
	p.addParameter('trackerMeshPath','./Resources/Vive_Tracker.stl',@ischar);
	p.addParameter('hmdMeshPath','./Resources/Vive_HMD.stl',@ischar);
	p.addParameter('controllerRedrawPeriod',0.05,@isscalar); % in s, requires relaunch if changed
	p.addParameter('controllerMeshFaceColor',[1 1 1]*0.3,@isvector);
	p.addParameter('controllerMeshFaceAlpha',1,@isscalar);
	% visualization - value readouts
	p.addParameter('doShowLiveXYZ',true,@islogical); % requires relaunch if changed
	p.addParameter('doShowLiveDistFromTarget',true,@islogical); % requires relaunch if changed
	p.addParameter('doShowLiveDistFromPrevious',true,@islogical); % requires relaunch if changed
	p.addParameter('doShowLiveMultitrackerAgreement',true,@islogical); % requires relaunch if changed
	
	p.parse(varargin{:});
	s = p.Results;
	
	s.persistentSettingsFields = {...
		'windowPosition',...
		'doSpeak',...
		'doSpeakVerbose',...
		'speechLexiconPath',...
		'templateMontagePath',...
		'doSampleRelativeTo_controller2',...
		'doSampleRelativeTo_tracker',...
		'doSampleRelativeTo_tracker2',...
		'doSampleRelativeTo_hmd',...
		'doRequireStableSample',...
		'stableSampleDistThreshold',...
		'doConnectOnStartup',...
		'doLaunchHelperExeAutomatically',...
		'helperExePath',...
		'digitizerCalibrationPath',...
		'doPlotElectrodes',...
		'doPlotFiducials',...
		'doPlotShapePts',...
		'doPlotTemplateElectrodes',...
		'doPlotTemplateFiducials',...
		'doPlotTemplateShapePts',...
		'doLabelElectrodes',...
		'doLabelFiducials',...
		'doLabelTemplateElectrodes',...
		'doLabelTemplateFiducials',...
		'meshPath',...
		'doPlotHeadMesh',...		
		'doPlotControllerMesh',...
		'doPlotTrackerMesh',...
		'doPlotHmdMesh',...
		'controllerMeshPath',...
		'trackerMeshPath',...
		'hmdMeshPath',...
		'doPlotControllerEndpoint',...
		'controllerRedrawPeriod',...
		'doShowLiveXYZ',...
		'doShowLiveDistFromTarget',...
		'doShowLiveDistFromPrevious',...
		'doShowLiveMultitrackerAgreement',...
	};
		
	%% misc initialization
	
	c_sayResetLevel();
	
	c_say('Initializing %s',mfilename);
	
	maxProgVal = 22;
	prog = c_progress(maxProgVal,'','doShowWaitbarOnly',true,'waitbarSimpleStr',sprintf('Initializing %s',mfilename));
	
	d = []; % digitizer object
	
	s.varargin = varargin;
	
	s.doClose = false;
	
	s.measuredMontageWasTransformed = false;
	
	s.previousXYZ = nan(1,3);
	
	guiH.callbackQueue = {};
	
	if isempty(s.templateMontage)
		s.templateMontage = c_DigitizedMontage();
	end
	if isempty(s.measuredMontage)
		s.measuredMontage = c_DigitizedMontage();
	end
	s.measuredMontageUnsaved = false;
	
	prog.update();
	
	%% construct GUI
	
	global g_VRDigitizerGUI_handle;
	if ~isempty(g_VRDigitizerGUI_handle) && ishandle(g_VRDigitizerGUI_handle)
		try
			close(g_VRDigitizerGUI_handle); % close previous
		catch
		end
	end
	
	prog.update();
	
	if exist(fullfile(s.basePath,s.persistentSettingsPath),'file')
		s.persistentSettingsPath = c_path_convert(fullfile(s.basePath,s.persistentSettingsPath),'toAbsolute');
		callback_persistentSettings_load(s.persistentSettingsPath);
	elseif exist(fullfile(s.basePath,'..',s.persistentSettingsPath),'file')
		s.basePath = fullfile(s.basePath,'..');
		s.persistentSettingsPath = c_path_convert(fullfile(s.basePath,s.persistentSettingsPath),'toAbsolute');
		callback_persistentSettings_load(s.persistentSettingsPath);
	else
		% when running for the first time (or after persistent settings are cleared),
		%  do some one-time initialization
		initializeOnFirstRun(p);
	end
	
	prog.update();
	
	launchHelperBeforeConnect = true;
	if s.doLaunchHelperExeAutomatically && launchHelperBeforeConnect
		callback_helper_launch();
	end
	
	prog.update();
	
	if ispc
		guiH.tts = c_TextToSpeech(...
			'doAsync',true,...
			'doAllowInterruption',true,...
			'Rate',1);
		guiH.tts.addLexicon('path',s.speechLexiconPath);
	else
		if s.doSpeak || s.doSpeakVerbose
			warning('Text to speech not supported on non-PC platform');
			s.doSpeak = false;
			s.doSpeakVerbose = false;
		end
	end
	
	prog.update();
	
	g_VRDigitizerGUI_handle = figure('name',mfilename,...
		'CloseRequestFcn',@(h,e) callback_GUI_CloseFigure(),...
		'MenuBar','none',...
		'Toolbar','figure',...
		'Visible','off');
	
	s.deleteCaller = c_RunCallbackOnDelete(@callback_GUI_CloseFigure);
	
	guiH.fig = g_VRDigitizerGUI_handle;
		
	prog.update();
	
	guiH.MeshHandle = [];
	guiH.TemplateMontageHandle = [];
	guiH.MeasuredMontageHandle = [];
	
	guiH.mainSplit = uix.HBoxFlex('parent',guiH.fig);
	guiH.controlsPanel = uipanel(guiH.mainSplit);
	guiH.viewPanel = uipanel(guiH.mainSplit);
	guiH.tablePanel = uipanel(guiH.mainSplit);
	
	set(guiH.mainSplit,'Widths',[300,-3, -1],'Spacing',5);
	
	prog.update();
	
	guiH.viewAxis = axes('parent',guiH.viewPanel);
	guiH.viewAxis.Visible = 'off';
	rotate3d(guiH.viewAxis,'on'); % enable rotation by default
	
	view(guiH.viewAxis,s.view);
	
	prog.update();
	
	guiH.tabgrp_controls = uitabgroup(guiH.controlsPanel,...
		'Position',[0 0 1 1],...
		'Units','normalized');
	
	%% other misc initialization
	
	% trackedDeviceKeys is exact match to list in VRDigitizerInterfacer
	% trackedDevices is list of devices for GUI
	% trackerKeys is trackedDevices minus the main controller
	% usedTrackerKeys is (dynamically changing) subset of trackerKeys that are actually being used
	if s.doSupportMultipleTrackers
		s.trackerKeys = s.trackedDeviceKeys(2:end);
		s.trackedDevices = s.trackedDeviceKeys;
		
		for iT_ = 1:length(s.trackerKeys)
			s.([s.trackerKeys{iT_} '_measuredMontage']) = c_DigitizedMontage();
		end
	else
		s.trackedDevices = {'controller','tracker'};
		s.trackerKeys = {'tracker'};
		otherDevs = setdiff(s.trackedDeviceKeys(2:end),s.trackerKeys);
		for iD_ = 1:length(otherDevs)
			s.(['doSampleRelativeTo_',otherDevs{iD_}]) = false;
		end
	end
	for iD_ = 1:length(s.trackedDevices)
		guiH.(['vrStatus_isTracking_' s.trackedDevices{iD_}]) = false;
	end
	updateUsedTrackerKeys();
	
	%% GUI components initialization
	
	prog.update();
	
	initializeControls_main();
	prog.update();
	
	initializeControls_settings();
	prog.update();
	
	initializeTableView();
	prog.update();
	
	%% post-GUI construction initialization
	
	if ~isempty(s.meshPath)
		callback_mesh_load(s.meshPath);
	end
	prog.update();
	
	if ~isempty(s.templateMontagePath)
		callback_templateMontage_load(s.templateMontagePath);
	end
	prog.update();
	
	if ~isempty(s.measuredMontagePath)
		s.measuredMontage = [];
		callback_measuredMontage_load(s.measuredMontagePath);
	else
		callback_measuredMontage_initEmpty();
	end
	prog.update();
	
	if ~isempty(s.controllerMeshPath)
		callback_controllerOrTrackerMesh_load(s.controllerMeshPath,'controller');
	end
	prog.update();
	
	if ~isempty(s.trackerMeshPath)
		callback_controllerOrTrackerMesh_load(s.trackerMeshPath,'tracker');
	end
	prog.update();
	
	if ~isempty(s.trackerMeshPath)
		callback_controllerOrTrackerMesh_load(s.hmdMeshPath,'hmd');
	end
	prog.update();
	
	if ~isempty(s.digitizerCalibrationPath)
		callback_digitizerCalibration_load(s.digitizerCalibrationPath);
	end
	prog.update();
	
	callback_stateMachine_init(s.doConnectOnStartup);
	
	if s.doLaunchHelperExeAutomatically && ~launchHelperBeforeConnect
		pause(2);
		callback_helper_launch();
	end
	prog.update();
	
	%% timers
	doDebugRedraw = false;
	
	if ~doDebugRedraw
		timerName = 'VRDigitizerGUIControllerRedrawTimer';

		% clear any previous timers
		tmp = timerfindall('Name',timerName);
		if ~isempty(tmp)
			stop(tmp);
			delete(tmp);
		end

		guiH.controllerRedrawTimer = timer(...
			'BusyMode','drop',...
			'ExecutionMode','fixedSpacing',...
			'Name','VRDigitizerGUIControllerRedrawTimer',...
			'Period',s.controllerRedrawPeriod,...
			'TimerFcn',@(h,e)callback_controller_redraw());

		start(guiH.controllerRedrawTimer);
	end
	
	prog.update();
	
	%% 
	drawnow; 
	prog.update();
	
	assert(prog.n == prog.N,'maxProgVal needs to be updated to %d',prog.n);
	
	prog.stop();
	
	% restore previous window position if specified
	if ~isempty(s.windowPosition)
		guiH.fig.Position = s.windowPosition;
	end
	
	set(guiH.fig,'Visible','on');
	
	drawnow;
	
	c_sayDone('Done initializing %s',mfilename);
	
	%% dispatcher to handle queued callbacks
	loopCount = 0;
	while ~s.doClose
		% dispatcher, as a workaround because https://www.mathworks.com/matlabcentral/answers/96855-is-it-possible-to-interrupt-timer-callbacks-in-matlab-7-14-r2012a
		if ~isempty(guiH.callbackQueue)
			%c_saySingle('Executing callback in queue');
			guiH.callbackQueue{end}();
			guiH.callbackQueue = guiH.callbackQueue(1:end-1);
		else
			drawnow;
			if doDebugRedraw && mod(loopCount,2)==0
				callback_controller_redraw()
			end
			pause(0.1);
			loopCount = mod(loopCount+1,10);
		end
		if loopCount == 0
			% if window is closed, break out of loop
			% check this less frequently since it is a relatively expensive operation
			if ~callback_figIsOpen()
				break;
			end
		end
	end
	
	%% callbacks
	
	function nonblockingCallback(callback)
		% add callback to dispatcher queue (note: it may not run immediately)
		guiH.callbackQueue{end+1} = callback;
	end
	
	function callback_GUI_CloseFigure()
		c_say('Closing %s',mfilename);
		
		% check if current measured montage is unsaved
		if s.doPromptIfClosingUnsaved && s.measuredMontageUnsaved
			if GUI_verify('Measured montage has not been saved. Save now?')
				callback_measuredMontage_save();
			end
		end
		
		% save current window position
		s.windowPosition = guiH.fig.Position;
		
		if s.doLaunchHelperExeAutomatically
			callback_helper_close();
		end
		
		if exist('s','var')
			s.deleteCaller.cancel();
			callback_persistentSettings_save(); % save persistent settings for next time
		end
		closereq();
	
		if ~isempty(d)
			d.close();
			d = [];
		end
	
		c_sayDone();
	end

	function callback_GUI_relaunch()
		callback_GUI_CloseFigure();
		
		VRDigitizerGUI(s.varargin{:});
		
		s.doClose = true;
	end

	%% 
	
	function initializeOnFirstRun(p)
		c_say('Performing first-run initialization');
		% convert all default paths from relative to absolute
		% (note: this is done here since we can't know the absolute "install" path until the first run)
		
		if ~exist(fullfile(s.basePath,'Resources'),'dir')
			% assume if resources are not in default basePath, that is because running as a compiled application where packaged 
			%  folders are located one directory above the folder containing VRDigitizerGUI.m
			altBasePath = fullfile(s.basePath,'..');
			if ~exist(fullfile(altBasePath,'Resources'),'dir')
				error('Resources directory not found in ''%s'' or ''%s''',s.basePath,altBasePath);
			end
			s.basePath = altBasePath;
		end
		
		c_say('Performing one-time path conversion');
		pathFieldsToConvert = {...
			'speechLexiconPath',...
			'templateMontagePath',...
			'helperExePath',...
			'digitizerCalibrationPath',...
			'meshPath',...
			'controllerMeshPath',...
			'trackerMeshPath',...
			'hmdMeshPath'};
		assert(all(ismember(pathFieldsToConvert,s.persistentSettingsFields)));
		pathFieldsToConvert = [pathFieldsToConvert,'persistentSettingsPath'];
		for iP = 1:length(pathFieldsToConvert)
			if ~ismember(pathFieldsToConvert{iP},p.UsingDefaults)
				% if a non-default path is specified, assume it is already absolute
				continue;
			end
			path = s.(pathFieldsToConvert{iP});
			if isempty(path)
				continue; 
			end
			path = c_path_convert(fullfile(s.basePath,path),'toAbsolute');
			s.(pathFieldsToConvert{iP}) = path;
		end
		c_sayDone();
		
		c_sayDone();
	end
		
	%% Main controls tab
	function initializeControls_main()
		guiH.tab_controls_main = uitab(guiH.tabgrp_controls,'Title','Main');
		guiH.tab_controls_main_panel = c_GUI_uix_VBox(...
			'Parent',guiH.tab_controls_main,...
			'doAllowScroll',true,...
			'Spacing',5);
		hp = guiH.tab_controls_main_panel;
		
		buttonHeight = 35;
		minFilefieldHeight = 80;
		filefieldHeight = minFilefieldHeight;
		indicatorHeight = 25;
		
		guiH.mainBtn_digitizerConnection = hp.add(...
			 uicontrol(...
				'style','pushbutton',...
				'Callback',@(h,e) nonblockingCallback(@callback_vr_init),...
				'String','Connect VR'),...
			'Height',buttonHeight);
		
		hgp = hp.add(uix.Grid('Spacing',5));
		
		gridHeights = [];
		guiH.vrStatus_connected = c_GUI_ColorIndicator(...
			'parent',hgp,...
			'Label','VR connection');
		gridHeights(end+1) = indicatorHeight;
		
		for iD = 1:length(s.trackedDevices)
			guiH.(['vrStatus_' s.trackedDevices{iD}]) = c_GUI_ColorIndicator(...
				'parent',hgp,...
				'Label',['VR ' prettifyTrackedDeviceStr(s.trackedDevices{iD})]);
			gridHeights(end+1) = indicatorHeight;
		end
		if s.doSupportMultipleTrackers
			gridHeights = gridHeights(1:ceil(length(gridHeights)/2));
			set(hgp,'Widths',[-1 -1],'Heights',gridHeights);
		else
			set(hgp,'Widths',[-1],'Heights',gridHeights);
		end
		hp.setLast('Height',sum(gridHeights+5*(length(gridHeights)-1)),'MinHeight',NaN);
		
		guiH.currentStateText = hp.add(@(parent)...
			c_GUI_Text(...
				'Parent',parent,...
				'String','',...
				'FontWeight','bold'),...
			'Height',50);
		
		if s.doShowLiveXYZ
			shp = hp.add(uipanel('Title','Live XYZ'),...
				'Height',50);
			guiH.liveXYZ = c_GUI_Text(...
				'parent',shp,...
				'String','');
		end
		
		if s.doShowLiveDistFromTarget
			shp = hp.add(uipanel('Title','Live dist from current'),...
				'Height',50);
			guiH.liveDistFromTarget = c_GUI_Text(...
				'parent',shp,...
				'String','');
		end
		
		if s.doShowLiveDistFromPrevious
			shp = hp.add(uipanel('Title','Live dist from previous'),...
				'Height',50);
			guiH.liveDistFromPrevious = c_GUI_Text(...
				'parent',shp,...
				'String','');
		end
		
		if s.doSupportMultipleTrackers && s.doShowLiveMultitrackerAgreement
			shp = hp.add(uipanel('Title','Live multitracker residuals'),...
				'Height',50);
			guiH.liveMultitrackerAgreement = c_GUI_Text(...
				'parent',shp,...
				'String','');
		end
	
		guiH.mainControlSubpanel = hp.add(uipanel('Title','Active controls'),...
			'Height',-3,...
			'MinHeight',250);
		
		buttonArgs = {...
			'style','pushbutton',...
			'String','',...
			'Callback',[],...
			'Units','normalized',...
			'FontSize',10,...
			'FontWeight','bold',...
			'Enable','off'};
		
		shp = c_GUI_uix_VBox(...
			'Parent',guiH.mainControlSubpanel,...
			'Spacing',0);
		
		sshp = shp.add(uix.HBox());
		uix.Empty('parent',sshp);
		guiH.mainBtn_top = uicontrol(buttonArgs{:},...
			'parent',sshp);
		uix.Empty('parent',sshp);
		set(sshp,'Widths',[-1 -2 -1]);
		
		sshp = shp.add(uix.HBox());
		uix.Empty('parent',sshp);
		guiH.mainBtn_up = uicontrol(buttonArgs{:},...
			'parent',sshp);
		uix.Empty('parent',sshp);
		set(sshp,'Widths',[-1 -2 -1]);
	
		sshp = shp.add(uix.HBox());
		guiH.mainBtn_left = uicontrol(buttonArgs{:},...
			'parent',sshp);
		guiH.mainBtn_right = uicontrol(buttonArgs{:},...
			'parent',sshp);
		set(sshp,'Widths',[-1 -1]);
		
		sshp = shp.add(uix.HBox());
		uix.Empty('parent',sshp);
		guiH.mainBtn_down = uicontrol(buttonArgs{:},...
			'parent',sshp);
		uix.Empty('parent',sshp);
		set(sshp,'Widths',[-1 -2 -1]);
		
		sshp = shp.add(uix.HBox());
		uix.Empty('parent',sshp);
		guiH.mainBtn_middle = uicontrol(buttonArgs{:},...
			'parent',sshp);
		uix.Empty('parent',sshp);
		set(sshp,'Widths',[-1 -2 -1]);
		
		sshp = shp.add(uix.HBox());
		uix.Empty('parent',sshp);
		guiH.mainBtn_bottom = uicontrol(buttonArgs{:},...
			'parent',sshp);
		uix.Empty('parent',sshp);
		set(sshp,'Widths',[-1 -2 -1]);
	
		guiH.measuredMontage_filefield = hp.add(@(parent)...
			c_GUI_FilepathField(...
				'label','Measured montage',...
				'mode','load-save',...
				'doIncludeClearButton',true,...
				'relativeTo',s.basePath,...
				'validFileTypes',{'*.pos;*.elp;*.3dd;*.montage.mat','Montage files'; '*.mat','Mat files'},...
				'loadCallback',@callback_measuredMontage_load,...
				'saveCallback',@callback_measuredMontage_save,...
				'clearCallback',@callback_measuredMontage_clear,...
				'parent',parent...
				),...
			'Height',filefieldHeight,...
			'MinHeight',minFilefieldHeight);
	end
	
	function callback_mainButtons_pushConfigToStack(varargin)
		% add a new set of labels and control callbacks for VR controller / GUI configurable buttons
		
		validator = @(x) isempty(x) || iscell(x) && length(x)==2 && ischar(x{1}) && isa(x{2},'function_handle');
		ip = inputParser();
		ip.addParameter('top',[],validator);
		ip.addParameter('up',[],validator);
		ip.addParameter('down',[],validator);
		ip.addParameter('left',[],validator);
		ip.addParameter('right',[],validator);
		ip.addParameter('middle',[],validator);
		ip.addParameter('bottom',[],validator);
		ip.addParameter('bottomReleased',[],validator);
		ip.addParameter('doNonBlockingCallbacks',true,@islogical);
		ip.parse(varargin{:});
	
		if ~c_isFieldAndNonEmpty(guiH,'mainButtonCallbacksStack')
			guiH.mainButtonCallbacksStack = {};
		end
	
		guiH.mainButtonCallbacksStack{end+1} = ip.Results;
	
		callback_mainButtons_showConfig(ip.Results);
	end
	
	function callback_mainButtons_popConfigFromStack()
		% restore previous set of labels and control callbacks for VR controller / GUI configurable buttons
		
		if length(guiH.mainButtonCallbacksStack) < 2
			GUIError('Stack would be empty after pop');
		end
		guiH.mainButtonCallbacksStack = guiH.mainButtonCallbacksStack(1:end-1);
		callback_mainButtons_showConfig(guiH.mainButtonCallbacksStack{end});
	end
	
	function callback_mainButtons_showConfig(config)
		% update labels and control callbacks for VR controller / GUI configurable buttons
		% (assumes config struct format as parsed in callback_mainButtons_pushConfigToStack)
	
		if nargin == 0
			config = guiH.mainButtonCallbacksStack{end};
		end
	
		buttonMap = containers.Map; % map from GUI button name to vive button name
		buttonMap('top') = 'menu';
		buttonMap('left') = 'trackpadLeft';
		buttonMap('right') = 'trackpadRight';
		buttonMap('up') = 'trackpadUp';
		buttonMap('down') = 'trackpadDown';
		buttonMap('middle') = 'trigger';
		buttonMap('bottom') = 'grip';
	
		highlightMap = containers.Map;
		highlightMap('left') = 'touchTrackpadLeft';
		highlightMap('right') = 'touchTrackpadRight';
		highlightMap('up') = 'touchTrackpadUp';
		highlightMap('down') = 'touchTrackpadDown';
		
		if ~callback_figIsOpen()
			% window has been closed
			return;
		end

		buttonNames = fieldnames(config);
		buttonNames = buttonNames(~ismember(buttonNames,{'text','doNonBlockingCallbacks','bottomReleased'}));
		for iB = 1:length(buttonNames)
			buttonHandle = guiH.(sprintf('mainBtn_%s',buttonNames{iB}));
			buttonHandle.Value = 0; % un-highlight
			if isempty(config.(buttonNames{iB})) || isempty(config.(buttonNames{iB}){1})
				buttonHandle.String = '';
			else
				buttonHandle.String = ['<html>' strrep(c_str_wrap(config.(buttonNames{iB}){1},'toLength',15),sprintf('\n'),'<br>') '</html>'];
			end
			if isempty(config.(buttonNames{iB})) || isempty(config.(buttonNames{iB}){2})
				buttonHandle.Callback = [];
				if c_isFieldAndNonEmpty(buttonHandle.UserData,'MousePressedCallbackSet')
					if buttonHandle.UserData.MousePressedCallbackSet
						try
							jb = findjobj(buttonHandle);
							jb.MousePressedCallback = [];
						catch
						end
					end
				end
				buttonHandle.Enable = 'off';
				if ~isempty(d)
					d.(sprintf('callback_btn_%sPressed',buttonMap(buttonNames{iB}))) = [];
					d.(sprintf('callback_btn_%sReleased',buttonMap(buttonNames{iB}))) = [];
					if highlightMap.isKey(buttonNames{iB}) && ~isempty(highlightMap(buttonNames{iB}))
						d.(sprintf('callback_btn_%sPressed', highlightMap(buttonNames{iB}))) = [];
						d.(sprintf('callback_btn_%sReleased',highlightMap(buttonNames{iB}))) = [];
					end
				end
			else
				pressCallback = config.(buttonNames{iB}){2};
				if c_isFieldAndNonEmpty(config,[buttonNames{iB} 'Released'])
					releaseCallback = config.([buttonNames{iB} 'Released']){2};
				else
					releaseCallback = [];
				end
				
				if config.doNonBlockingCallbacks
					pressCallback = @(~,~) nonblockingCallback(pressCallback);
					if ~isempty(releaseCallback)
						releaseCallback = @(~,~) nonblockingCallback(releaseCallback);
					end
				end
				
				if isempty(buttonHandle.UserData)
					buttonHandle.UserData = struct();
				end
				
				if isempty(releaseCallback)
					buttonHandle.Callback = pressCallback;
					buttonHandle.UserData.MousePressedCallbackSet = false;
				else
					try
						jb = findjobj(buttonHandle); % from http://undocumentedmatlab.com/blog/uicontrol-callbacks
						jb.MousePressedCallback = pressCallback;
						buttonHandle.Callback = releaseCallback;
						buttonHandle.UserData.MousePressedCallbackSet = true;
					catch
					end
				end
				
				buttonHandle.Enable = 'on';
				
				if ~isempty(d)
					d.(sprintf('callback_btn_%sPressed',buttonMap(buttonNames{iB}))) = pressCallback;
					if ~isempty(releaseCallback)
						d.(sprintf('callback_btn_%sReleased',buttonMap(buttonNames{iB}))) = releaseCallback;
					end
					if highlightMap.isKey(buttonNames{iB}) && ~isempty(highlightMap(buttonNames{iB}))
						d.(sprintf('callback_btn_%sPressed', highlightMap(buttonNames{iB}))) = @(~) set(buttonHandle,'Value',1); % highlight
						d.(sprintf('callback_btn_%sReleased',highlightMap(buttonNames{iB}))) = @(~) set(buttonHandle,'Value',0); % un-highlight
					end
				end
			end
		end
	end
	
	function gotoMainTab()
		c_saySingle('going to main tab');
		guiH.tabgrp_controls.SelectedTab = guiH.tab_controls_main;
	end

	%% settings tab
	function initializeControls_settings()
		guiH.tab_controls_settings = uitab(guiH.tabgrp_controls,'Title','Main settings');
		guiH.tab_controls_settings_panel = c_GUI_uix_VBox(...
			'Parent',guiH.tab_controls_settings,...
			'doAllowScroll',true,...
			'Spacing',5);
		hp = guiH.tab_controls_settings_panel;
		
		minFilefieldHeight = 80;
		filefieldHeight = minFilefieldHeight;
		checkboxHeight = 20;
		buttonHeight = 40;
		
		createCheckbox = @(hp,string,settingField)...
			hp.add(uicontrol(...
					'Style','checkbox',...
					'String',string,...
					'Callback',@(h,e) callback_updateSetting(settingField,h.Value>0),...
					'Value',s.(settingField)),...
				'Height',checkboxHeight);
			
		createPlotCheckbox = @(hp,string, settingField, varargin)...
			hp.add(uicontrol(...
					'Style','checkbox',...
					'String',string,...
					'Callback',@(h,e) callback_updatePlotSetting(settingField,h.Value>0,varargin{:}),...
					'Value',s.(settingField)),...
				'Height',checkboxHeight);
		
		createSpace = @(hp) hp.add(uix.Empty(),'Height',checkboxHeight/2);
		
		createText = @(hp,string,varargin) hp.add(uicontrol(...
				'Style','text',...
				'HorizontalAlignment','left',...
				'String',string,...
				varargin{:}),...
			'Height',checkboxHeight*0.8*(sum(string==sprintf('\n'))+1));
		
		guiH.templateMontage_filefield = hp.add(@(parent)...
			c_GUI_FilepathField(...
				'label','Template montage',...
				'mode','load-only',...
				'doIncludeClearButton',true,...
				'validFileTypes',{'*.pos;*.elp;*.3dd;*.montage.mat','Montage files'; '*.mat','Mat files'},...
				'loadCallback',@callback_templateMontage_load,...
				'clearCallback',@callback_templateMontage_clear,...
				'relativeTo',s.basePath,...
				'parent',parent...
				),...
			'Height',filefieldHeight,...
			'MinHeight',minFilefieldHeight);
		
		createSpace(hp);
		
		guiH.digitizerCalibration_filefield = hp.add(@(parent)...
			c_GUI_FilepathField(...
				'label','Calibration file',...
				'mode','load-save',...
				'validFileTypes','*.mat',...
				'doIncludeClearButton',true,...
				'loadCallback',@callback_digitizerCalibration_load,...
				'saveCallback',@callback_digitizerCalibration_save,...
				'clearCallback',@callback_digitizerCalibration_clear,...
				'relativeTo',s.basePath,...
				'parent',parent...
				),...
			'Height',filefieldHeight,...
			'MinHeight',minFilefieldHeight);
		
		guiH.digitizerCalibrationStartButton = hp.add(uicontrol(...
				'style','pushbutton',...
				'String','Calibrate pointer',...
				'Callback',@(~,~) callback_stateMachine_transitionTo('calibratingDigitizer')),...
			'Height',buttonHeight);
		
		createSpace(hp); 
		
		createText(hp,'Measure relative to:','FontWeight','bold');
		createText(hp,'  (select none to disable head tracking)');
		
		for iT = 1:length(s.trackerKeys)
			guiH.(['checkbox_useTracker_' s.trackerKeys{iT}]) = hp.add(uicontrol(...
					'Style','checkbox',...
					'String',c_str_toTitleCase(s.trackerKeys{iT}),...
					'Callback',@(h,e) callback_updateTrackerSetting(s.trackerKeys{iT},h.Value>0),...
					'Value',s.(['doSampleRelativeTo_' s.trackerKeys{iT}])),...
				'Height',checkboxHeight);
		end
		createSpace(hp);
		
		createCheckbox(hp,'Require stable samples','doRequireStableSample');
		hp.add(@(parent)...
			c_GUI_EditField(...
				'Parent',parent,...
				'Label','Stability threshold (mm)',...
				'Value',c_convertValuesFromUnitToUnit(s.stableSampleDistThreshold,s.distUnit,'mm'),...
				'ValueOutputConverter',@(x) c_convertValuesFromUnitToUnit(x,'mm',s.distUnit),...
				'ValueOutputValidator',@isscalar,...
				'Callback',@(h,e) callback_updateSetting('stableSampleDistThreshold',h.Value)),...
			'Height',checkboxHeight);
		
		createSpace(hp); 
		
		createSpace(hp); 
		
		createCheckbox(hp,'Speak basic','doSpeak');
		createCheckbox(hp,'Speak verbose','doSpeakVerbose');
		
		createSpace(hp);
		createCheckbox(hp,'Connect on startup','doConnectOnStartup');
		createCheckbox(hp,'Launch helper automatically','doLaunchHelperExeAutomatically');
		
		createSpace(hp);
		
		hgp = hp.add(uix.HBox('Spacing',5),'Height',buttonHeight);
		uicontrol(...
			'parent',hgp,...
			'style','pushbutton',...
			'String','Launch helper',...
			'Callback',@(h,e) callback_helper_launch());
		uicontrol(...
			'parent',hgp,...
			'style','pushbutton',...
			'String','Close helper',...
			'Callback',@(h,e) callback_helper_close());
		set(hgp,'Widths',[-1 -1]);	
		
		%%
		
		guiH.tab_controls_settings_visualization = uitab(guiH.tabgrp_controls,'Title','Visualization settings');
		guiH.tab_controls_settings_visualization_panel = c_GUI_uix_VBox(...
			'Parent',guiH.tab_controls_settings_visualization,...
			'doAllowScroll',true,...
			'Spacing',5);
		hp = guiH.tab_controls_settings_visualization_panel;
		
		createText(hp,'Measured montage:','FontWeight','bold');
		createPlotCheckbox(hp,	'Plot measured electrodes',		'doPlotElectrodes',			'measuredMontage'); 
		createPlotCheckbox(hp,	'Label measured electrodes',	'doLabelElectrodes',		'measuredMontage'); 
		createPlotCheckbox(hp,	'Plot measured fiducials',		'doPlotFiducials',			'measuredMontage'); 
		createPlotCheckbox(hp,	'Label measured fiducials',		'doLabelFiducials',			'measuredMontage'); 
		createPlotCheckbox(hp,	'Plot measured shape points',	'doPlotShapePts',			'measuredMontage'); 
		
		createSpace(hp);
		createText(hp,'Template montage:','FontWeight','bold');
		createPlotCheckbox(hp,	'Plot template electrodes',		'doPlotTemplateElectrodes',	'templateMontage'); 
		createPlotCheckbox(hp,	'Label template electrodes',	'doLabelTemplateElectrodes','templateMontage'); 
		createPlotCheckbox(hp,	'Plot template fiducials',		'doPlotTemplateFiducials',	'templateMontage'); 
		createPlotCheckbox(hp,	'Label template fiducials',		'doLabelTemplateFiducials',	'templateMontage'); 
		createPlotCheckbox(hp,	'Plot template shape points',	'doPlotTemplateShapePts',	'templateMontage'); 
		
		createSpace(hp);
		createText(hp,'Head mesh:','FontWeight','bold');
		createPlotCheckbox(hp,	'Plot head mesh',		'doPlotHeadMesh',			'headMesh'); 
		guiH.mesh_filefield = hp.add(@(parent)...
			c_GUI_FilepathField(...
				'label','Head mesh',...
				'mode','load-only',...
				'doIncludeClearButton',true,...
				'validFileTypes',{'*.stl;*.fsmesh;*.off;*.mesh.mat','Mesh files'; '*.mat', 'Mat files'},...
				'loadCallback',@callback_mesh_load,...
				'clearCallback',@callback_mesh_clear,...
				'relativeTo',s.basePath,...
				'parent',parent...
				),...
			'Height',filefieldHeight,...
			'MinHeight',minFilefieldHeight);
				
		createSpace(hp);
		createText(hp,'Tracked devices:','FontWeight','bold');
		createCheckbox(hp,'Draw live controller endpoint','doPlotControllerEndpoint');
		createCheckbox(hp,'Draw live controller(s)','doPlotControllerMesh');
		createCheckbox(hp,'Draw live tracker(s)','doPlotTrackerMesh');
		createCheckbox(hp,'Draw live HMD','doPlotHmdMesh');
		
		createSpace(hp);
		
		createCheckboxRequiringRestart = @(hp, string, settingField) ...
			hp.add(uicontrol(...
					'Style','checkbox',...
					'String',string,...
					'Callback',@(h,e) callback_updateSettingRequiringRelaunch(settingField,h.Value>0,h,s.(settingField)),...
					'Value',s.(settingField)),...
				'Height',checkboxHeight);
			
		createCheckboxRequiringRestart(hp,'Show live XYZ','doShowLiveXYZ');
		createCheckboxRequiringRestart(hp,'Show live dist from target','doShowLiveDistFromTarget');
		createCheckboxRequiringRestart(hp,'Show live dist from previous','doShowLiveDistFromPrevious');
		
		hp.add(@(parent)...
			c_GUI_EditField(...
				'Parent',parent,...
				'Label','Live redraw period (ms)',...
				'Value',c_convertValuesFromUnitToUnit(s.controllerRedrawPeriod,'s','ms'),...
				'ValueOutputConverter',@(x) c_convertValuesFromUnitToUnit(x,'ms','s'),...
				'ValueOutputValidator',@(x) isscalar(x) && x > 0,...
				'Callback',@(h,e) callback_updateSettingRequiringRelaunch('controllerRedrawPeriod',h.Value,h,...
					c_convertValuesFromUnitToUnit(s.controllerRedrawPeriod,'s','ms'))),...
			'Height',checkboxHeight);
		
		guiH.controllerMesh_filefield = hp.add(@(parent)...
			c_GUI_FilepathField(...
				'label','Controller mesh',...
				'mode','load-only',...
				'doIncludeClearButton',true,...
				'validFileTypes',{'*.stl;*.fsmesh;*.off;*.mesh.mat','Mesh files'; '*.mat', 'Mat files'},...,...
				'loadCallback',@(fn) callback_controllerOrTrackerMesh_load(fn,'controller'),...
				'clearCallback',@(fn) callback_controllerOrTrackerMesh_clear(fn,'controller'),...
				'relativeTo',s.basePath,...
				'parent',parent...
				),...
			'Height',filefieldHeight,...
			'MinHeight',minFilefieldHeight);
		
		guiH.trackerMesh_filefield = hp.add(@(parent)...
			c_GUI_FilepathField(...
				'label','Tracker mesh',...
				'mode','load-only',...
				'doIncludeClearButton',true,...
				'validFileTypes',{'*.stl;*.fsmesh;*.off;*.mesh.mat','Mesh files'; '*.mat', 'Mat files'},...,...
				'loadCallback',@(fn) callback_controllerOrTrackerMesh_load(fn,'tracker'),...
				'clearCallback',@(fn) callback_controllerOrTrackerMesh_clear(fn,'tracker'),...
				'relativeTo',s.basePath,...
				'parent',parent...
				),...
			'Height',filefieldHeight,...
			'MinHeight',minFilefieldHeight);
		
		guiH.hmdMesh_filefield = hp.add(@(parent)...
			c_GUI_FilepathField(...
				'label','HMD mesh',...
				'mode','load-only',...
				'doIncludeClearButton',true,...
				'validFileTypes',{'*.stl;*.fsmesh;*.off;*.mesh.mat','Mesh files'; '*.mat', 'Mat files'},...,...
				'loadCallback',@(fn) callback_controllerOrTrackerMesh_load(fn,'hmd'),...
				'clearCallback',@(fn) callback_controllerOrTrackerMesh_clear(fn,'hmd'),...
				'relativeTo',s.basePath,...
				'parent',parent...
				),...
			'Height',filefieldHeight,...
			'MinHeight',minFilefieldHeight);
		
	end

	function callback_updateSetting(setting, value)
		
		if ismember(setting, cellfun(@(x) ['doSampleRelativeTo_' x], s.trackerKeys,'UniformOutput',false))
			callback_updateTrackerSettings(setting,value);
			return;
		end
		
		assert(isfield(s,setting));
		
		c_saySingle('Changing s.%s to %s',setting,c_toString(value));
		
		s.(setting) = value;
	end

	function callback_updateTrackerSetting(trackerKey,value)
		% handle some specific callbacks that must be called when changing which trackers are used
		
		assert(ismember(trackerKey,s.trackerKeys));
		
		setting = ['doSampleRelativeTo_' trackerKey];
		
		if c_isFieldAndNonEmpty(s,'measuredMontage')
			if s.measuredMontage.numFiducials > 0
				if ~GUI_verify('Changing this setting will require re-measuring fiducials. Continue anyways?')
					guiH.(['checkbox_useTracker_' trackerKey]).Value = s.(setting); % undo change to GUI control
					return
				end
			end
		end
			
		assert(isfield(s,setting));
		
		c_saySingle('Changing s.%s to %s',setting,c_toString(value));
		
		s.(setting) = value;
		
		updateUsedTrackerKeys();
		
		% update tracking indicators to indicate when we are or are not paying attention to which tracker
		callback_vr_updateTrackingIndicators();
	end

	function callback_updatePlotSetting(setting, value, plotToRefresh) 
		
		assert(isfield(s,setting));
		
		s.(setting) = value;
		
		if nargin > 2
			switch(plotToRefresh)
				case 'measuredMontage'
					callback_measuredMontage_redraw();
				case 'templateMontage'
					callback_templateMontage_redraw();
				case 'headMesh'
					callback_mesh_redraw();
				otherwise
					warning('No redraw action for plotToRefresh %s',category);
			end
		end
	end

	function callback_updateSettingRequiringRelaunch(setting, value, h, revertValue)
		if value ~= revertValue
			resp = GUI_dialog(sprintf('Changing ''%s'' requires relaunch.',setting),...
				'responses',{'Cancel','Relaunch now','Relaunch later (!)'},...
				'default','Relaunch now');
			switch(resp)
				case 'Cancel'
					h.Value = revertValue;
					c_saySingle('Cancelled change of ''%s''',setting);
				case 'Relaunch now'
					s.(setting) = value;
					callback_GUI_relaunch();
				case 'Relaunch later (!)'
					s.(setting) = value;
					warning('Chose to relaunch later after changing ''%s''. This may cause errors / unexpected behavior.',setting);
				otherwise
					error('Unexpected response: %s',resp);
			end
		else
			% no change needed
		end
	end
	

	%% endpoint calibration

	function callback_digitizerCalibration_load(filepath)
		if ~exist(filepath,'file')
			warning('File does not exist at %s',filepath);
			return;
		end
		c_say('Loading endpoint calibration from %s',filepath);
		tmp = load(filepath,'offset','distUnit');
		callback_digitizerCalibration_setNewOffset(tmp.offset,tmp.distUnit);
		c_sayDone();
		guiH.digitizerCalibration_filefield.path = filepath;
		s.digitizerCalibrationPath = filepath;
	end
	
	function callback_digitizerCalibration_save(filepath)
		if nargin==0
			guiH.digitizerCalibration_filefield.simulateButtonPress('save to...');
			return; % above function should have called this callback with argument
		end
		c_say('Saving endpoint calibration to %s',filepath);
		if isempty(d.XYZOffset)
			warning('Device calibration is empty');
		end
		tmp = struct('offset',c_convertValuesFromUnitToUnit(d.XYZOffset,s.vr_distUnit,s.distUnit),'distUnit',s.distUnit);
		save(filepath,'-struct','tmp');
		c_sayDone();
		guiH.digitizerCalibration_filefield.path = filepath;
		s.digitizerCalibrationPath = filepath;
	end
	
	function callback_digitizerCalibration_clearPts()
		c_saySingle('Clearing endpoint calibration measurements');
		s.digitizerCalibration.rawMeasurements = [];
	end
	
	function callback_digitizerCalibration_clearDeviceCalibration()
		c_saySingle('Clearing endpoint calibration');
		if ~isempty(d)
			d.XYZOffset = [];
		end
	end
	
	function callback_digitizerCalibration_clear(~)
		s.digitizerCalibrationPath = [];
		callback_digitizerCalibration_clearDeviceCalibration();
	end
	
	function callback_processNewCalibrationMeasurement(rawMeasurement)
		assert(isstruct(rawMeasurement));
	
		if ~c_isFieldAndNonEmpty(s.digitizerCalibration,'rawMeasurements')
			s.digitizerCalibration.rawMeasurements = rawMeasurement;
			s.digitizerCalibration.rawMeasurements(1) = [];
		end
	
		c_saySingleMultiline('New calibration measurement: %s',c_toString(rawMeasurement));
	
		iC = s.currentStateVars.calibrationCounter;
		iC = min(iC,length(s.digitizerCalibration.rawMeasurements)+1);
	
		s.digitizerCalibration.rawMeasurements(iC) = rawMeasurement;
	
		s.currentStateVars.calibrationCounter = iC + 1;
		
		callback_updateStateText();
	end
	
	function callback_digitizerCalibration_processPts()
		minNumPts = 3;
		if ~c_isField(s.digitizerCalibration,'rawMeasurements') || length(s.digitizerCalibration.rawMeasurements) < minNumPts
			GUIError('At least %d points are required for calibration',minNumPts);
		end
		
		d.pausePolling();
	
		optimizationMethod = 'fmincon';
		doPlot = true;
	
		maxOffset = c_convertValuesFromUnitToUnit(50,'cm',s.vr_distUnit);
		
		calTransfs = d.getTransfFromSpaceToSpace('controller','global',s.digitizerCalibration.rawMeasurements);
		numPts = size(calTransfs,3);
		
		if 1
			filePath = fullfile('./',['CalibrationRaw_' c_str_timestamp() '.mat']);
			save(filePath,'calTransfs');
			c_saySingle('Saved raw calibration data to %s',filePath)
		end
		
		function cost = fitnessFcn(x)
			transfPts = nan(numPts,3);
			for iPp = 1:numPts
				transfPts(iPp,:) = c_pts_applyRigidTransformation(x,calTransfs(:,:,iPp));
			end
			cost = sum(c_norm(bsxfun(@minus,transfPts,mean(transfPts,1)),'2sq',2));
		end
		
		maxOffset = repmat(maxOffset,1,3);
		c_say('Calculating offset value from %d calibration points',numPts);
		
		switch(optimizationMethod)
			case 'fmincon'
				calculatedOffset = fmincon(@fitnessFcn,[0 0 0],[],[],[],[],-maxOffset,maxOffset);
			case 'pso'
				calculatedOffset = pso(@fitnessFcn,3,[],[],[],[],-maxOffset,maxOffset,[]);
			otherwise
				GUIError('Invalid optimizationMethod: %s',optimizationMethod);
		end
		c_saySingle('Calculated offset: %s',c_toString(calculatedOffset));
		c_sayDone();
	
		if doPlot
			hf = figure('name','Digitizer calibration');
			if ~isempty(guiH.controllerMesh)
				c_subplot('position',[0 0 0.7 1]);
			end
			
			plotDistUnit = 'mm';
			
			pts = nan(numPts,3);
			for iP = 1:numPts
				pts(iP,:) = c_pts_applyRigidTransformation(calculatedOffset,calTransfs(:,:,iP));
			end
			pts = c_convertValuesFromUnitToUnit(pts,s.vr_distUnit,plotDistUnit);
			origin = mean(pts,1);
			
			if ~isempty(guiH.controllerMesh)
				for iP = 1:numPts
					tmpMesh = guiH.controllerMesh;
					tmpMesh.DistUnit = s.distUnit;
					tmpMesh = c_mesh_applyTransform(tmpMesh,...
						'quaternion',transfConvertDistUnits(calTransfs(:,:,iP),s.vr_distUnit,tmpMesh.DistUnit));
					tmpMesh.Vertices = bsxfun(@minus,tmpMesh.Vertices,origin);
					c_mesh_plot(tmpMesh,...
						'distUnit',plotDistUnit,...
						'faceColor',s.controllerMeshFaceColor,...
						'faceAlpha',0.2);
					hold on
				end
			end
			
			relPts = [];
			for iP = 1:numPts
				relPts(:,:,iP) = [0 0 0;
							calculatedOffset];
				relPts = c_pts_applyRigidTransformation(relPts(:,:,iP),calTransfs(:,:,iP));
				relPts = c_convertValuesFromUnitToUnit(relPts,s.vr_distUnit,plotDistUnit);
				relPts = bsxfun(@minus,relPts,origin);
				args = c_mat_sliceToCell(relPts,2);
				line(args{:},'Marker','.');
				c_plot_scatter3(relPts(end,:),'ptSizes',3);
				xlabel(sprintf('X (%s)',plotDistUnit));
				ylabel(sprintf('Y (%s)',plotDistUnit));
				zlabel(sprintf('Z (%s)',plotDistUnit));
				hold on;
			end
			%title('Reoriented calibration measurements');
			axis equal
			dists = c_norm(bsxfun(@minus,pts,mean(pts,1)),2,2);
			str = 'Reoriented calibration measurements';
			str = [str, sprintf('\n\tCalibration samples deviation from mean:\n')];
			str = [str, sprintf('Mean: %.3g %s\n', mean(dists),plotDistUnit)];
			str = [str, sprintf('Median: %.3g %s\n', median(dists),plotDistUnit)];
			str = [str, sprintf('Max: %.3g %s\n', max(dists),plotDistUnit)];
			if 1
				c_saySingleMultiline(str);
			else
				title(str)
			end
			view(3)
			
			if ~isempty(guiH.controllerMesh)
				c_subplot('position',[0.7 0 0.3 1]);
				c_mesh_plot(guiH.controllerMesh,...
					'faceColor',s.controllerMeshFaceColor,...
					'faceAlpha',s.controllerMeshFaceAlpha);
				tmp = c_convertValuesFromUnitToUnit(calculatedOffset,s.vr_distUnit,s.distUnit);
				c_plot_scatter3(tmp,...
					'ptColors',[1 0 0],...
					'ptSizes',c_convertValuesFromUnitToUnit(3,'mm',s.distUnit));
				%title('Endpoint relative to controller');
			end
			c_fig_arrange('top-right',hf);
				
			callback_digitizerCalibration_clearPts();
			
% 			c_say('Pausing to view calibration')
% 			pause
% 			c_sayDone();
		end
		
		d.resumePolling();
		
		callback_digitizerCalibration_setNewOffset(calculatedOffset,s.vr_distUnit);
	end
	
	function callback_digitizerCalibration_setNewOffset(offset,distUnit)
		s.digitizerCalibration.offset = offset;
		s.digitizerCalibration.distUnit = distUnit;
		if ~isempty(d)
			d.XYZOffset = c_convertValuesFromUnitToUnit(offset, distUnit, s.vr_distUnit);
		end
		c_saySingle('Setting digitizer endpoint offset to %s mm',c_toString(...
			c_convertValuesFromUnitToUnit(offset, distUnit,'mm'),'precision',5));
	end
	
	%% table view
	
	function initializeTableView()
		
		guiH.tableVBox = uix.VBox('Parent',guiH.tablePanel,'Spacing',5);
		
		XYZWidth = 120;
		NumWidth = 40;
		
		hFP = uipanel('Title','Fiducials',...
			'parent',guiH.tableVBox);
		guiH.fiducialTable = uitable(hFP,...
			'ColumnWidth',{'auto',XYZWidth,XYZWidth,NumWidth,NumWidth},...
			'ColumnName',{'Label','Template XYZ (mm)','Measured XYZ (mm)','T #','M #'},...
			'CellSelectionCallback',@(h,e) callback_tableSelectionChanged('fiducial',h,e),...
			'Units','normalized',...
			'Position',[0 0 1 1]);
		guiH.fiducialTable_jh = findjobj(guiH.fiducialTable);
		
		hEP = uipanel('Title','Electrodes',...
			'parent',guiH.tableVBox);
		guiH.electrodeTable = uitable(hEP,...
			'ColumnWidth',{'auto',XYZWidth,XYZWidth,NumWidth,NumWidth},...
			'ColumnName',{'Label','Template XYZ (mm)','Measured XYZ (mm)','T #','M #'},...
			'CellSelectionCallback',@(h,e) callback_tableSelectionChanged('electrode',h,e),...
			'Units','normalized',...
			'Position',[0 0 1 1]);
		guiH.electrodeTable_jh = findjobj(guiH.electrodeTable);
		
		hSP = uipanel('Title','Shape points',...
			'parent',guiH.tableVBox);
		guiH.shapePtTable = uitable(hSP,...
			'ColumnWidth',{XYZWidth,XYZWidth},...
			'ColumnName',{'Template XYZ (mm)','Measured XYZ (mm)'},...
			'CellSelectionCallback',@(h,e) callback_tableSelectionChanged('shapePt',h,e),...
			'Units','normalized',...
			'Position',[0 0 1 1]);
		guiH.shapePtTable_jh = findjobj(guiH.shapePtTable);
		
		set(guiH.tableVBox,'Heights',[-1 -4 -2]);
	
		callback_table_redraw();
	end
	
	function callback_table_redraw()
		% extract fiducials, electrodes, and shape points from both measured and template montages
		convertEmptyStructs = @(x) c_if(isstruct(x) && c_isEmptyStruct(x),[],x);
		if ~isempty(s.measuredMontage)
			mFiducials = convertEmptyStructs(s.measuredMontage.fiducials);
			mElectrodes = convertEmptyStructs(s.measuredMontage.electrodes);
			mShapePts = convertEmptyStructs(s.measuredMontage.shapePoints);
		else
			mFiducials = [];
			mElectrodes = [];
			mShapePts = [];
		end
	
		if ~isempty(s.templateMontage)
			tFiducials = convertEmptyStructs(s.templateMontage.fiducials);
			tElectrodes = convertEmptyStructs(s.templateMontage.electrodes);
			tShapePts = convertEmptyStructs(s.templateMontage.shapePoints);
		else
			tFiducials = [];
			tElectrodes = [];
			tShapePts = [];
		end
		
		rowHeight = 22;
	
		[allFidLabels, indicesInTemplate, indicesInMeasured] = getCombinedFiducialList();
		
		numFiducials = length(allFidLabels);
		
		% assumes there are no duplicate labels within montages (other than possibly in fiducials)
		allElecLabels = {};
		if ~isempty(tElectrodes)
			allElecLabels = [allElecLabels, {tElectrodes.label}];
		end
		if ~isempty(mElectrodes)
			allElecLabels = [allElecLabels, {mElectrodes.label}];
		end
		allElecLabels = unique(allElecLabels,'stable');
		numElectrodes = length(allElecLabels);
		
		numShapePts = max(length(mShapePts),length(tShapePts));
		
		elemToXYZStr = @(x,distUnit) sprintf('[%6.1f, %6.1f, %6.1f]',round(...
			c_convertValuesFromUnitToUnit(c_struct_mapToArray(x,{'X','Y','Z'}),distUnit,'mm'),1));
		
		% fiducials
		numColumns = length(guiH.fiducialTable.ColumnName);
		numRows = numFiducials+1;
		data = cell(numRows,numColumns);
		for iF = 1:numFiducials
			dataRow = cell(1,numColumns);
			label = allFidLabels{iF};
            iMF = indicesInMeasured(iF);
            iTF = indicesInTemplate(iF);
			
			if ~isnan(iTF)
				if ~isnan(iMF)
					dataRow{1} = tFiducials(iTF).label;
				else
					% add html formatting to indicate fiducial not in measured montage
					dataRow{1} = sprintf('<html><i>%s</i></html>',tFiducials(iTF).label);
				end
				dataRow{2} = elemToXYZStr(tFiducials(iTF),s.templateMontage.distUnit);
				dataRow{4} = iTF;
			end
			
			if ~isnan(iMF)
				if ~isnan(iTF)
					% already labeled above
				else
					dataRow{1} = sprintf('<html><b>%s</b></html>',mFiducials(iMF).label);
				end
				dataRow{3} = elemToXYZStr(mFiducials(iMF),s.measuredMontage.distUnit);
				dataRow{5} = iMF;
			end
			data(iF,:) = dataRow;
		end
		guiH.fiducialTable.Data = data;
		
		% electrodes
		numColumns = length(guiH.electrodeTable.ColumnName);
		numRows = numElectrodes+1;
		data = cell(numRows,numColumns);
		for iE = 1:numElectrodes
			dataRow = cell(1,numColumns);
			label = allElecLabels{iE};
			if ~isempty(mElectrodes)
				iME = find(ismember({mElectrodes.label},label)); assert(length(iME) <= 1);
			else
				iME = [];
			end
			if ~isempty(tElectrodes)
				iTE = find(ismember({tElectrodes.label},label)); assert(length(iTE) <= 1);
				if ~isempty(iTE)
					if ~isempty(iME)
						dataRow{1} = tElectrodes(iTE).label;
					else
						dataRow{1} = sprintf('<html><i>%s</i></html>',tElectrodes(iTE).label);
					end
					dataRow{2} = elemToXYZStr(tElectrodes(iTE),s.templateMontage.distUnit);
					dataRow{4} = iTE;
				end
			end
			if ~isempty(iME)
				if ~isempty(iME)
					% already labeled above
				else
					dataRow{1} = sprintf('<html><b>%s</b></html>',mElectrodes(iME).label);
				end
				dataRow{3} = elemToXYZStr(mElectrodes(iME),s.measuredMontage.distUnit);			
				dataRow{5} = iME;
			end
			data(iE,:) = dataRow;
		end
		guiH.electrodeTable.Data = data;
		
		% shape points
		numColumns = 2;
		numRows = numShapePts+1;
		data = cell(numRows,numColumns);
		for iS = 1:numShapePts
			dataRow = cell(1,numColumns);
			if iS <= length(tShapePts)
				dataRow{1} = elemToXYZStr(tShapePts(iS),s.templateMontage.distUnit);
			end
			if iS <= length(mShapePts)
				dataRow{2} = elemToXYZStr(mShapePts(iS),s.measuredMontage.distUnit);
			end
			data(iS,:) = dataRow;
		end
		guiH.shapePtTable.Data = data;
	end

	function callback_table_changeSelectionTo(whichTable,row,column)
		switch(whichTable)
			case 'fiducial'
				ht = guiH.fiducialTable;
				hjscroll = guiH.fiducialTable_jh;
			case 'electrode'
				ht = guiH.electrodeTable;
				hjscroll = guiH.electrodeTable_jh;
			case 'shapePt'
				ht = guiH.shapePtTable;
				hjscroll = guiH.shapePtTable_jh;
			otherwise
				error('Invalid whichTable: %s',whichTable);
		end
		
		% undocumented code, could break
		% adapted from https://stackoverflow.com/questions/19634250/how-to-deselect-cells-in-uitable-how-to-disable-cell-selection-highlighting
		try
			assert(isa(hjscroll,'javahandle_withcallbacks.com.mathworks.hg.peer.utils.UIScrollPane'));
			hjviewport = paren(hjscroll.getComponents(),1);
			assert(isa(hjviewport,'javax.swing.JViewport'));
			hjtablepeer = paren(hjviewport.getComponents(),1);
			assert(isa(hjtablepeer,'com.mathworks.hg.peer.ui.UITablePeer$23'));

			curColumn = hjtablepeer.getSelectedColumn()+1;
			curRow = hjtablepeer.getSelectedRow()+1;
			if curColumn ~= column || curRow ~= row

				if curColumn > 0 && curRow > 0
					try
						cr = hjtablepeer.getCellRenderer(curColumn-1, curRow-1);
						crf = cr.getForeground();
						cr.setForeground(crf.black);
					catch
					end
				end

				tmpCallback = ht.CellSelectionCallback;
				ht.CellSelectionCallback = [];
				drawnow;
				pause(0.01);
				hjtablepeer.changeSelection(row-1,column-1,false,false);
				drawnow;
				ht.CellSelectionCallback = tmpCallback;
			else
				% specified row, column already selected
				% do nothing
			end
		catch e
			warning('Problem with changeSelectionTo: %s',e.message);
		end
	end
	
	function callback_tableSelectionChanged(whichTable,h,e)
		if isempty(e.Indices)
			% table un-selected
			return;
		else
			rowNumSelected = e.Indices(1);
			% (if multiple selected, this just looks at the first selected row)
		end
		
		assert(ismember(whichTable,{'fiducial','electrode','shapePt'}));
		
		callback_stateMachine_jumpToMeasuringState(['recording' upper(whichTable(1)) whichTable(2:end) 's'],rowNumSelected);
	end


	%% state machine
	
	function callback_stateMachine_init(doConnect)
		s.currentState = 'initialization';
		s.currentStateVars = struct();
		if doConnect
			nonblockingCallback(@(~) callback_stateMachine_transitionTo('connecting'));
		else
			nonblockingCallback(@(~) callback_stateMachine_transitionTo('ready'));
		end
	end
	
	function callback_stateMachine_transitionTo(toState)
		fromState = s.currentState;
	
		c_saySingle('Requested transition from ''%s'' to ''%s''',fromState,toState);
		
		commonButtonArgs = {...
			'bottom',			{'Change view',@(~,~) callback_startViewInteraction()},...
			'bottomReleased',	{'Change view',@(~,~) callback_stopViewInteraction()},...
		};
	
		triggerPrevNextDoneConfigArgs = {...
			commonButtonArgs{:},...
			'middle',{'Sample',@(~,~) callback_triggerMeasurement()},...
			'down',{'Next',@(~,~) callback_stateMachine_changeActiveCounter(+1)},...
			'up',{'Prev',@(~,~) callback_stateMachine_changeActiveCounter(-1)},...
			'left',{'Clear',@(~,~) callback_clearMeasurement()},...
			'right',{'Sample',@(~,~) callback_triggerMeasurement()},...
			'top',{'Done',@(~,~) callback_stateMachine_transitionTo('ready')}};
		
		switch(fromState)
			case 'initialization'
				switch(toState)
					case 'connecting'
						callback_mainButtons_pushConfigToStack();
					case 'ready'
						callback_mainButtons_pushConfigToStack(...
							commonButtonArgs{:},...
							'left',{'Record fiducials',@(~,~) callback_stateMachine_transitionTo('recordingFiducials')},...
							'down',{'Record electrodes',@(~,~) callback_stateMachine_transitionTo('recordingElectrodes')},...
							'right',{'Record shape points',@(~,~) callback_stateMachine_transitionTo('recordingShapePts')});
					otherwise
						GUIError('Unsupported state transition from %s to %s',fromState, toState);
				end
			case 'connecting'
				switch(toState)
					case 'ready'
						callback_mainButtons_pushConfigToStack(...
							commonButtonArgs{:},...
							'left',{'Record fiducials',@(~,~) callback_stateMachine_transitionTo('recordingFiducials')},...
							'down',{'Record electrodes',@(~,~) callback_stateMachine_transitionTo('recordingElectrodes')},...
							'right',{'Record shape points',@(~,~) callback_stateMachine_transitionTo('recordingShapePts')});
					case 'connecting'
						% do nothing
					otherwise
						GUIError('Unsupported state transition from %s to %s',fromState, toState);
				end
			case 'ready'
				gotoMainTab();
				
				switch(toState)
					case 'calibratingDigitizer'
						speakVerbose('Switching to digitizer calibration','doAllowInterruption',false);
						s.currentStateVars = struct();
						s.currentStateVars.calibrationCounter = 1;
						callback_mainButtons_pushConfigToStack(triggerPrevNextDoneConfigArgs{:});
					case 'recordingFiducials'
						speakVerbose('Switching to fiducial recording','doAllowInterruption',false);
						s.currentStateVars = struct();
						s.currentStateVars.fiducialCounter = 1;
						callback_mainButtons_pushConfigToStack(triggerPrevNextDoneConfigArgs{:});
					case 'recordingElectrodes'
						if isempty(s.measurementTransform)
							if ~GUI_verify('Fiducials not yet measured or processed. Continue anyways?')
								c_saySingle('Cancelled state transition');
								return;
							end
						end
						speakVerbose('Switching to electrode recording','doAllowInterruption',false);
						s.currentStateVars = struct();
						s.currentStateVars.electrodeCounter = 1;
						callback_mainButtons_pushConfigToStack(triggerPrevNextDoneConfigArgs{:});
					case 'recordingShapePts'
						if isempty(s.measurementTransform)
							if ~GUI_verify('Fiducials not yet measured or processed. Continue anyways?')
								c_saySingle('Cancelled state transition');
								return;
							end
						end
						speakVerbose('Switching to shape point recording','doAllowInterruption',false);
						s.currentStateVars = struct();
						s.currentStateVars.shapePtCounter = 1;
						callback_mainButtons_pushConfigToStack(triggerPrevNextDoneConfigArgs{:});
					case 'ready'
						% do nothing
					otherwise
						GUIError('Unsupported state transition from %s to %s',fromState, toState);
				end
			case 'calibratingDigitizer'
				switch(toState)
					case 'ready'
						speakVerbose('Processing digitizer calibration points');
						callback_digitizerCalibration_processPts();
						if GUI_verify('Save calibration to file?')
							callback_digitizerCalibration_save();
						end
						speakVerbose('Done with digitizer calibration');
						callback_mainButtons_popConfigFromStack();
					otherwise
						callback_stateMachine_transitionTo('ready');
						callback_stateMachine_transitionTo(toState);
				end
			case 'recordingFiducials'
				switch(toState)
					case 'ready'
						if GUI_verify('Process fiducials?')
							didFail = callback_measuredMontage_processFiducials();
							if ~didFail
								speakVerbose('Done digitizing fiducials');
							else
								speakVerbose('Processing of fiducials failed. Restarting fiducial measurement.');
								s.currentStateVars = struct();
								s.currentStateVars.fiducialCounter = 1;
								return; % cancel state transition, stay in recordingFiducials
							end
						else
							speakVerbose('Processing of fiducials cancelled');
						end
						callback_table_changeSelectionTo('fiducial',0,0);
						callback_mainButtons_popConfigFromStack();
					otherwise
						callback_stateMachine_transitionTo('ready');
						callback_stateMachine_transitionTo(toState);
				end
			case 'recordingElectrodes'
				switch(toState)
					case 'ready'
						% do nothing
						speakVerbose('Done digitizing electrodes');
						callback_table_changeSelectionTo('electrode',0,0);
						callback_mainButtons_popConfigFromStack();
					otherwise
						callback_stateMachine_transitionTo('ready');
						callback_stateMachine_transitionTo(toState);
				end
			case 'recordingShapePts'
				switch(toState)
					case 'ready'
						% do nothing
						speakVerbose('Done digitizing shape points');
						callback_table_changeSelectionTo('shapePt',0,0);
						callback_mainButtons_popConfigFromStack();
					otherwise
						callback_stateMachine_transitionTo('ready');
						callback_stateMachine_transitionTo(toState);
				end
			
			otherwise
				GUIError('Unsupported current state: %s',fromState);
		end
	
		s.currentState = toState;
	
		callback_updateStateText();
	
		c_saySingle('StateMachine: Transitioned from ''%s'' to ''%s''',fromState, toState);
		
		if strcmp(s.currentState,'connecting')
			callback_vr_init();
			callback_stateMachine_transitionTo('ready');
		end
	end
	
	function callback_updateStateText()
		if ~callback_figIsOpen
			% GUI has been closed
			return;
		end
		
		str = sprintf('State: %s',c_str_fromCamelCase(s.currentState));
		switch(s.currentState)
			case 'calibratingDigitizer'
				iC = s.currentStateVars.calibrationCounter;
				str = [str,sprintf('\nNext sample: calibration point %d',iC)];
				speak(sprintf('%d',iC));
			case 'recordingFiducials'
				iF = s.currentStateVars.fiducialCounter;
				if isempty(s.templateMontage) || ~c_isFieldAndNonEmpty(s.templateMontage,'fiducialLabels')
					GUIError('Template montage must specify fiducials');
				end
                
                allFidLabels = getCombinedFiducialList();
            
                if iF <= length(allFidLabels) || 1
					fidLabel = getNthFiducialLabel(allFidLabels, iF);
					str = [str,sprintf('\nNext sample: %s (%d/%d)',fidLabel,iF,length(allFidLabels))];
					speak(sprintf('%s',allFidLabels{iF}));
                else
                    str = [str, sprintf('\nReached end of fiducial list')];
					%speak('End of fiducial list');
				end
				callback_table_changeSelectionTo('fiducial',iF,1);
			case 'recordingElectrodes'
				iE = s.currentStateVars.electrodeCounter;
				electrodeLabels = s.templateMontage.electrodeLabels;
				if iE <= length(electrodeLabels)
					str = [str,sprintf('\nNext sample: %s (%d/%d)',electrodeLabels{iE},iE,length(electrodeLabels))];
					speak(sprintf('%s',electrodeLabels{iE}));
				else
					str = [str, sprintf('\nReached end of electrode list')];
					str = [str, sprintf('\nNext sample: electrode #%d',iE)];
					speak(sprintf('Elec %d',iE));
				end
				callback_table_changeSelectionTo('electrode',iE,1);
			case 'recordingShapePts'
				iP = s.currentStateVars.shapePtCounter;
				str = [str, sprintf('\nNext sample: %d (out of %d)',iP,s.measuredMontage.numShapePoints)];
				speak(sprintf('%d',iP));
				callback_table_changeSelectionTo('electrode',0,0);
			otherwise
				% do nothing
		end
	
		guiH.currentStateText.String = str;
	end
	
	function callback_stateMachine_changeActiveCounter(change,newVal)
		if nargin > 1
			assert(isempty(change));
		else
			newVal = [];
		end
		switch(s.currentState)
			case 'calibratingDigitizer'
				if ~c_isFieldAndNonEmpty(s.digitizerCalibration,'rawMeasurements')
					maxVal = 1;
				else
					maxVal = length(s.digitizerCalibration.rawMeasurements)+1;
				end
				if isempty(change)
					change = newVal - s.currentStateVars.calibrationCounter;
				end
				s.currentStateVars.calibrationCounter = min(max(s.currentStateVars.calibrationCounter+change,1),maxVal);
			case 'recordingFiducials'
				maxVal = s.measuredMontage.numFiducials+1;
				if isempty(change)
					change = newVal - s.currentStateVars.fiducialCounter;
				end
				s.currentStateVars.fiducialCounter = min(max(s.currentStateVars.fiducialCounter+change,1),maxVal);
			case 'recordingElectrodes'
				maxVal = s.measuredMontage.numElectrodes+1;
				if ~isempty(s.templateMontage)
					maxVal = max(maxVal,s.templateMontage.numElectrodes);
				end
				if isempty(change)
					change = newVal - s.currentStateVars.electrodeCounter;
				end
				s.currentStateVars.electrodeCounter = min(max(s.currentStateVars.electrodeCounter+change,1),maxVal);
			case 'recordingShapePts'
				maxVal = s.measuredMontage.numShapePoints+1;
				if isempty(change)
					change = newVal - s.currentStateVars.shapePtCounter;
				end
				s.currentStateVars.shapePtCounter = min(max(s.currentStateVars.shapePtCounter+change,1),maxVal);
			otherwise
				GUIError('No active counter in state %s',s.currentState);
		end
		callback_updateStateText();
	end

	function callback_stateMachine_jumpToMeasuringState(whichState,newCounter)
		if nargin < 2
			newCounter = 1;
		end
		
		assert(ismember(whichState,{'recordingFiducials','recordingElectrodes','recordingShapePts'}));
		
		if ~isequal(whichState,s.currentState)
			% must change state before setting counter
			callback_stateMachine_transitionTo(whichState);
		end
		
		callback_stateMachine_changeActiveCounter([],newCounter);	
	end
	
	function callback_processNewMeasurement(XYZ,rawMeasurement)
		% assumes XYZ is already in s.distUnit
		
		if strcmp(s.currentState,'calibratingDigitizer')
			% do not apply transform or measure with respect to tracker during calibration
			callback_processNewCalibrationMeasurement(rawMeasurement);
			return;
		end

		if ~isempty(s.measurementTransform) && ~isempty(XYZ)
			XYZ = c_pts_applyRigidTransformation(XYZ,s.measurementTransform);
		end
		
		if ~isempty(XYZ)
			s.previousXYZ = XYZ;
		end
	
		switch(s.currentState)
			case 'ready'
				% discard measurement
				c_saySingle('Measurement received in waiting state. Discarding.');
			case 'recordingFiducials'
				callback_processNewFiducialMeasurement(XYZ,rawMeasurement);
			case 'recordingElectrodes'
				callback_processNewElectrodeMeasurement(XYZ);
			case 'recordingShapePts'
				callback_processNewShapePtMeasurement(XYZ);
			otherwise
				warning('Processing of new measurement not supported in %s state. Discarding.',s.currentState);
		end
		callback_updateStateText();
	end
	
	function callback_processNewFiducialMeasurement(XYZ,rawMeasurement)
		% pull fiducial names from template montage
		fiducialLabels = s.templateMontage.fiducialLabels;
		
		if isempty(fiducialLabels)
			warning('No fiducial labels in template montage. Using hardcoded fiducials.');
			fiducialLabels = {'LPA','NAS','RPA','NoseTip'};
		end
		
		iF = s.currentStateVars.fiducialCounter;
	
		if 0
			% do not allow repeated measurements
			if iF > length(fiducialLabels)
				c_saySingle('Resetting fiducial counter to beginning');
				s.currentStateVars.fiducialCounter = 1;
			end
			fiducialLabel = fiducialLabels{s.currentStateVars.fiducialCounter};
		else
			% start repeating fiducials from beginning if at end of list
			if iF > length(fiducialLabels)
				uniqueFiducialLabels = unique(fiducialLabels,'stable');
				fiducialLabel = uniqueFiducialLabels{mod(iF-1,length(uniqueFiducialLabels))+1};
			else
				fiducialLabel = fiducialLabels{iF};
			end
		end
	
		if isempty(XYZ)
			% empty input indicates we should clear current measurement without progressing
			s.measuredMontage.setFiducial('byIndex',iF,'XYZ',nan(1,3),'label',fiducialLabel);
			if s.doSupportMultipleTrackers
				for iT = 1:length(s.trackerKeys)
					if s.([s.trackerKeys{iT} '_measuredMontage']).numFiducials >= iF
						s.([s.trackerKeys{iT} '_measuredMontage']).setFiducial('byIndex',iF,'XYZ',nan(1,3),'label',fiducialLabel);
					end
				end
			end
		else
			s.measuredMontage.setFiducial('byIndex',iF,'XYZ',XYZ,...
				'label',fiducialLabel,...
				'distUnit',s.distUnit);
			
			if s.doSupportMultipleTrackers && ~isempty(s.usedTrackerKeys)
				assert(~isempty(d) && d.isConnected);
				[XYZs, trackerKeys] = d.convertFromRawTo('XYZswrtTrackers',rawMeasurement);
				assert(isequal(sort(trackerKeys),sort(s.usedTrackerKeys)));
				for iT = 1:length(trackerKeys)
					if any(isnan(XYZs(iT,:)))
						% reject measurement if one of the used trackers was not tracking 
						warning('A tracker was not tracking. Dropping fiducial measurement.');
						return;
					end
					s.([trackerKeys{iT} '_measuredMontage']).setFiducial('byIndex',iF,'XYZ',XYZs(iT,:),...
						'label',fiducialLabel,...
						'distUnit',d.distUnit);
				end
			end

			c_saySingle('Recorded fiducial ''%s'' at %s.',fiducialLabel,c_toString(XYZ,'precision',8));
			if 0
				if s.currentStateVars.fiducialCounter == length(fiducialLabels)
					c_saySingle('Reached end of fiducial list');
				end
			end

			s.currentStateVars.fiducialCounter = s.currentStateVars.fiducialCounter + 1;
		end
		
		s.measuredMontageUnsaved = true;
		
		%callback_updateStateText();
		callback_measuredMontage_redraw();
		callback_table_redraw();
	end
	
	function callback_processNewElectrodeMeasurement(XYZ)
		iE = s.currentStateVars.electrodeCounter;
	
		if iE <= s.templateMontage.numElectrodes
			% pull electrode label from template montage
			eLabel = s.templateMontage.electrodeLabels{iE};
		elseif iE <= s.measuredMontage.numElectrodes
			% pull electrode name from measured montage
			eLabel = s.measuredMontage.electrodeLabels{iE};
		else
			eLabel = ''; % add new electrode (name will be autogenerated)
		end
	
		if isempty(XYZ)
			% empty input indicates we should clear current measurement without progressing
			if isempty(eLabel) || ~ismember(eLabel,s.measuredMontage.getElectrodeLabels())
				% electrode label already doesn't exist
				% (do nothing)
			else
				s.measuredMontage.setElectrode(eLabel,'XYZ',nan(1,3));
			end
		else
			if ~isempty(eLabel)
				s.measuredMontage.setElectrode(eLabel,'XYZ',XYZ,'distUnit',s.distUnit);
			else
				s.measuredMontage.addElectrodes('XYZ',XYZ,'distUnit',s.distUnit);
				eLabel = s.measuredMontage.electrodeLabels{end};
			end
			c_saySingle('Recorded electrode ''%s'' at %s',eLabel,c_toString(XYZ,'precision',8));
	
			s.currentStateVars.electrodeCounter = s.currentStateVars.electrodeCounter + 1;
		end
	
		s.measuredMontageUnsaved = true;
		
		%callback_updateStateText();
		callback_measuredMontage_redraw();
		callback_table_redraw();
	end
	
	function callback_processNewShapePtMeasurement(XYZ)
		iP = s.currentStateVars.shapePtCounter;
		
		if isempty(XYZ)
			% empty input indicates we should clear current measurement without progressing
			s.measuredMontage.setShapePoint(iP,'XYZ',nan(1,3));
		else
			s.measuredMontage.setShapePoint(iP,'XYZ',XYZ,'distUnit',s.distUnit);

			c_saySingle('Recorded shape point %d at %s',iP,c_toString(XYZ,'precision',8));

			s.currentStateVars.shapePtCounter = s.currentStateVars.shapePtCounter + 1;
		end
	
		s.measuredMontageUnsaved = true;
		
		%callback_updateStateText();
		callback_measuredMontage_redraw();
		callback_table_redraw();
	end
	
	
	%% Digitizer interfacing
	
	function isOpen = callback_figIsOpen()
		isOpen = ishandle(guiH.fig);
	end

	function callback_helper_launch()
		assert(ispc);
		[~,processName,~] = fileparts(s.helperExePath);
		if ~exist(s.helperExePath,'file')
			warning('File does not exist at %s. Not launching helper',s.helperExePath);
			pause(1);
			return;
		end
		
		[status,result] = system(sprintf('tasklist /FI "imagename eq %s.exe" /fo table /nh',processName));
		isRunning = ~strcmpi(strtrim(result),'INFO: No tasks are running which match the specified criteria.');
		if ~isRunning
			c_saySingle('Launching %s',s.helperExePath);
			[status,out] = system(sprintf('start /b %s >nul 2>&1',strrep(s.helperExePath,' ','" "')));
			assert(status==0);
		end
	end

	function callback_helper_close()
		[~,processName,~] = fileparts(s.helperExePath);
		[status,result] = system(sprintf('tasklist /FI "imagename eq %s.exe" /fo table /nh',processName));
		isRunning = ~strcmpi(strtrim(result),'INFO: No tasks are running which match the specified criteria.');
		if isRunning
			c_saySingle('Killing %s.exe',processName);
			[status, result] = system(sprintf('taskkill /IM %s.exe /F',processName));
		end
	end

	function updateUsedTrackerKeys()
		isUsed = false(1,length(s.trackerKeys));
		for iT = 1:length(s.trackerKeys)
			isUsed(iT) = s.(['doSampleRelativeTo_',s.trackerKeys{iT}]);
		end
		s.usedTrackerKeys = s.trackerKeys(isUsed);
		
		%TODO: could add code to not reset transforms if only reducing trackers being used (i.e. if old transforms from subset of trackers can still be used)
		
		% reset measured fiducials, since they'll have to be remeasured to get data for aligning the new set of trackers
		
		if c_isFieldAndNonEmpty(s,'measuredMontage')
			s.measuredMontage.deleteFiducials('all',true);
		end
		
		for iT = 1:length(s.trackerKeys)
			s.([s.trackerKeys{iT} '_measuredMontage']).deleteFiducials('all',true);
		end
		
		if c_isFieldAndNonEmpty(s,'trackerTransforms')
			c_saySingle('Resetting tracker transforms. Must remeasure fiducials to align trackers.');
			s.trackerTransforms = [];
		end
		
		if ~isempty(d)
			d.trackerKeys = s.usedTrackerKeys;
			% this will reset d's trackerTransforms
		end
	end
	
	function callback_vr_init()
		if ~isempty(d)
			d = []; % delete/close previous
		end
	
		c_say('Initializing VR connection');
		speakVerbose('Connecting to VR system');
		guiH.mainBtn_digitizerConnection.String = 'Connecting to VR system...';
		guiH.mainBtn_digitizerConnection.Callback = @(h,e) callback_vr_disconnect();
		guiH.mainBtn_digitizerConnection.Enable = 'on';
		guiH.vrStatus_connected.Color = [1 1 1]*0.5;
		
		for iD = 1:length(s.trackedDevices)
			guiH.(['vrStatus_' s.trackedDevices{iD}]).Color = [1 1 1]*0.5;
		end
		
        drawnow();
	
		guiH.vr_keepTryingToConnect = true;
		
		d = VRDigitizerInterfacer(...
			'ip',s.vr_ip,...
			'port',s.vr_port,...
			'callback_connected',@callback_vr_updateConnectionStatus,...
			'callback_keepTryingToConnect',@callback_vr_keepTryingToConnect,...
			'callback_disconnected',@callback_vr_disconnected,...
			'callback_trackingChange',@callback_vr_trackingChange,...
			'doPollAutomatically',true);
	
		assert(isequal(s.trackedDeviceKeys,d.trackedDeviceKeys));
		
		if s.doSupportMultipleTrackers
			d.trackerKeys = s.usedTrackerKeys;
			if c_isFieldAndNonEmpty(s,'trackerTransforms')
				d.trackerTransforms = transfConvertDistUnits(s.trackerTransforms,s.distUnit,d.distUnit);
			end
		end
		
		if ~callback_figIsOpen()
			% figure was closed during connection attempt
			c_sayDone();
			return;
		end
		
		if ~d.isConnected
			warning('vr connect failed');
			speakVerbose('VR connect failed');
		else
			c_saySingle('VR successfully connected');
			speakVerbose('VR connected');
		end
	
		if c_isFieldAndNonEmpty(s.digitizerCalibration,'offset')
			callback_digitizerCalibration_setNewOffset(s.digitizerCalibration.offset,s.digitizerCalibration.distUnit);
		end
	
		c_sayDone('VR initialization complete');
	
		callback_vr_updateConnectionStatus();
	
		callback_mainButtons_showConfig();
	end

	function doKeepTrying = callback_vr_keepTryingToConnect()
		doKeepTrying = callback_figIsOpen() && guiH.vr_keepTryingToConnect;
	end

	function callback_vr_disconnect()
		c_say('Disconnecting VR');
		if ~isempty(d)
			d.close();
			d = [];
		end
		
		guiH.vr_keepTryingToConnect = false; % termine any pending connection attempts
		
		callback_vr_updateConnectionStatus();
		c_sayDone('done disconnecting vr');
	end
		
	function callback_vr_disconnected()
		c_saySingle('VR disconnected.');
		if ~callback_figIsOpen()
			return
		end
		speakVerbose('VR disconnected.');
		callback_vr_updateConnectionStatus();
	end

	function callback_vr_updateConnectionStatus()
		isConnected = ~isempty(d) && d.isConnected();
	
		if ~callback_figIsOpen()
			% window already closed
			return;
		end
	
		if isConnected
			guiH.mainBtn_digitizerConnection.String = 'Disconnect VR';
			guiH.mainBtn_digitizerConnection.Callback = @(h,e) callback_vr_disconnect();
			guiH.mainBtn_digitizerConnection.Enable = 'on';
			guiH.vrStatus_connected.Color = [0 0.7 0];
		else
			guiH.mainBtn_digitizerConnection.String = 'Connect VR';
			guiH.mainBtn_digitizerConnection.Callback = @(h,e) callback_vr_init();
			guiH.mainBtn_digitizerConnection.Enable = 'on';
			guiH.vrStatus_connected.Color = [1 0 0];
		end
		
		callback_vr_updateTrackingIndicators();
		%drawnow();
	end

	function callback_vr_updateTrackingIndicators(whichDev)
		if nargin < 1
			whichDevs = s.trackedDevices;
		else
			whichDevs = {whichDev};
		end
		
		isConnected = ~isempty(d) && d.isConnected();
		
		assert(all(ismember(whichDevs,s.trackedDeviceKeys)));
		for iD = 1:length(whichDevs)
			if ~isConnected
				guiH.(['vrStatus_' whichDevs{iD}]).Color = [1 1 1]*0.5;
				continue;
			end
			
			isTracking = guiH.(['vrStatus_isTracking_' whichDevs{iD}]);
			
			if ismember(whichDevs{iD},s.trackerKeys)
				if ~s.(['doSampleRelativeTo_',whichDevs{iD}])
					if isTracking
						% use a different color if tracking but not actually using data
						guiH.(['vrStatus_' whichDevs{iD}]).Color = [0.5 0.6 0.5]; 
					else
						guiH.(['vrStatus_' whichDevs{iD}]).Color = [0.7 0.5 0.5]; 
					end
					continue;
				end
			end
			
			if isTracking
				guiH.(['vrStatus_' whichDevs{iD}]).Color = [0 0.7 0];
			else
				guiH.(['vrStatus_' whichDevs{iD}]).Color = [1 0 0];
			end
		end
	end

	function callback_vr_trackingChange(whichDev, isTracking)
		if isTracking
			color = [0 0.7 0];
		else
			color = [1 0 0];
		end
		
		assert(ismember(whichDev,s.trackedDeviceKeys),'Unrecognized device: %s',whichDev);
		
		if ~ismember(whichDev,s.trackedDevices)
			return;
		end
		
		guiH.(['vrStatus_isTracking_' whichDev]) = isTracking;
		
		callback_vr_updateTrackingIndicators(whichDev);
		
		c_saySingle('VR %s %s tracking',whichDev,c_if(isTracking,'is','is not'));
	end

	%% Controller mesh
	
	function callback_controllerOrTrackerMesh_load(filepath,controllerOrTracker)
		if ~strcmp(guiH.([controllerOrTracker 'Mesh_filefield']).path,filepath)
			guiH.([controllerOrTracker 'Mesh_filefield']).path = filepath;
		end
		if ~exist(filepath,'file')
			warning('File does not exist at %s',filepath);
			return;
		end
		c_say('Loading %s mesh from %s',controllerOrTracker,filepath);
		mesh = c_mesh_load(filepath);
		[~,mesh] = c_mesh_isValid(mesh); % save validated mesh so that it doesn't need to be revalidated in the future
		guiH.([controllerOrTracker 'Mesh']) = mesh;
		s.([controllerOrTracker 'MeshPath']) = guiH.([controllerOrTracker 'Mesh_filefield']).path;
		% draw full mesh for first time here, then just change mesh vertex positions when updating in redraw (to be more efficient)
		if s.doSupportMultipleTrackers && ~strcmpi(controllerOrTracker,'hmd')
			numRepeats = 2; % assume up to two each of controller and tracker
		else
			numRepeats = 1;
		end
		for iR = 1:numRepeats
			numberedControllerOrTracker = controllerOrTracker;
			if iR > 1
				numberedControllerOrTracker = [numberedControllerOrTracker num2str(iR)];
			end
			guiH.([numberedControllerOrTracker 'MeshHandle'])= c_mesh_plot(guiH.([controllerOrTracker 'Mesh']),...
						'view',[],...
						'faceColor',s.controllerMeshFaceColor,...
						'faceAlpha',s.controllerMeshFaceAlpha,...
						'axis',guiH.viewAxis);
			set(guiH.([numberedControllerOrTracker 'MeshHandle']),'Visible','off');
		end
		callback_controller_redraw();
		c_sayDone();
	end

	function callback_controllerOrTrackerMesh_clear(~,controllerOrTracker)
		guiH.([controllerOrTracker 'Mesh'])= [];
		callback_controller_redraw();
	end

	function callback_controller_redraw()
  		try 
		if ~callback_figIsOpen()
			return;
		end
		
		if s.doSupportMultipleTrackers
			controllerOrTrackerStrs = {'controller','controller2','tracker','tracker2','hmd'};
		else
			controllerOrTrackerStrs = {'controller','tracker'};
		end
		for i=1:length(controllerOrTrackerStrs)
			numberedControllerOrTracker = controllerOrTrackerStrs{i};
			if c_isFieldAndNonEmpty(guiH,[numberedControllerOrTracker 'MeshHandle'])
				if 0
					delete(guiH.([numberedControllerOrTracker 'MeshHandle']));
					guiH.([numberedControllerOrTracker 'MeshHandle']) = [];
				else
					set(guiH.([numberedControllerOrTracker 'MeshHandle']),'visible','off');
				end
			end
		end
		
		if c_isFieldAndNonEmpty(guiH,'ControllerEndpointHandle')
			delete(guiH.ControllerEndpointHandle);
			guiH.ControllerEndpointHandle = [];
		end
		
		if isempty(d) || ~d.isConnected()
			% nothing to plot if digitizer is not connected
			
			if s.doShowLiveXYZ
				guiH.liveXYZ.String = '';
			end
			if s.doShowLiveDistFromTarget
				guiH.liveDistFromTarget.String = '';
			end
			if s.doShowLiveDistFromPrevious
				guiH.liveDistFromPrevious.String = '';
			end
			
			if s.doSupportMultipleTrackers && s.doShowLiveMultitrackerAgreement
				guiH.liveMultitrackerAgreement.String = '';
			end
			
			return;
		end
		
		msg = d.getMostRecent('RawMeasurement');
		
		for i=1:length(controllerOrTrackerStrs)
			numberedControllerOrTracker = controllerOrTrackerStrs{i};
			if ismember(numberedControllerOrTracker(end),'0123456789')
				controllerOrTracker = numberedControllerOrTracker(1:end-1); % assume only ever a single digit for numbering
			else
				controllerOrTracker = numberedControllerOrTracker; % no number
			end
			controllerOrTracker_upper = [upper(controllerOrTracker(1)) controllerOrTracker(2:end)];
		
			if s.(['doPlot' controllerOrTracker_upper 'Mesh']) && c_isFieldAndNonEmpty(guiH,[controllerOrTracker 'Mesh'])
				%c_say('Redrawing %s mesh', controllerOrTracker);
				if ~isempty(s.usedTrackerKeys)
					whatToGet = {'transf',numberedControllerOrTracker,s.usedTrackerKeys{1}}; % note this plots everything with respect to first tracker, not average of trackers
					% (this is due to possible complexities of averaging transforms)
				else
					whatToGet = {'transf',numberedControllerOrTracker,'global'};
				end
				transf = d.convertFromRawTo(whatToGet,msg);
				
				%c_saySingle('Transf: %s',c_toString(transf));
				if ~all(isnan(transf(:)))
					
					transf = transfConvertDistUnits(transf,s.vr_distUnit,s.distUnit);
					
					if ~isempty(s.measurementTransform)
						transf = s.measurementTransform*transf;
					end

					tmpMesh = c_mesh_applyTransform(guiH.([controllerOrTracker 'Mesh']),...
							'quaternion',transf);
					if 0
						guiH.([numberedControllerOrTracker 'MeshHandle']) = c_mesh_plot(tmpMesh,...
							'view',[],...
							'faceColor',s.controllerMeshFaceColor,...
							'faceAlpha',s.controllerMeshFaceAlpha,...
							'axis',guiH.viewAxis);
					else
						set(guiH.([numberedControllerOrTracker 'MeshHandle']),'Vertices',tmpMesh.Vertices,'Visible','on');
					end
				else
					if 0
						delete(guiH.([numberedControllerOrTracker 'MeshHandle']));
						guiH.([numberedControllerOrTracker 'MeshHandle']) = [];
					else
						set(guiH.([numberedControllerOrTracker 'MeshHandle']),'visible','off');
					end
				end
				%c_sayDone();
			end
		end

		
		
		if s.doPlotControllerEndpoint || s.doShowLiveXYZ || s.doShowLiveDistFromTarget || s.doShowLiveDistFromPrevious ...

			if strcmp(s.currentState,'calibratingDigitizer')
				whatToGet = 'XYZUncorrected';
			elseif ~isempty(s.usedTrackerKeys)
				whatToGet = {'XYZ','pointer',s.usedTrackerKeys{1}}; % note this plots everything with respect to first tracker, not average of trackers
			else
				whatToGet = 'XYZ';
			end
			XYZ = d.convertFromRawTo(whatToGet,msg);
			XYZ = c_convertValuesFromUnitToUnit(XYZ,s.vr_distUnit,s.distUnit);
			if ~isempty(s.measurementTransform)
				XYZ = c_pts_applyTransform(XYZ,'quaternion',s.measurementTransform);
			end
			
			if s.doShowLiveXYZ
				guiH.liveXYZ.String = sprintf('%.2f %.2f %.2f mm',c_convertValuesFromUnitToUnit(XYZ,s.distUnit,'mm'));
			else
				%c_saySingle('Live XYZ: %s',c_toString(XYZ));
			end
			
			if c_isFieldAndNonEmpty(guiH,'viewInteraction_isOngoing') && guiH.viewInteraction_isOngoing
				% update view based on controller pos
				
				origin = [0 0 0]; %TODO: could alternatively calculate origin from center of mesh, etc.
				
				if isempty(guiH.viewInteraction_startPos)
					guiH.viewInteraction_startPos = XYZ;
					camtarget(guiH.viewAxis,origin);
					guiH.viewInteraction_startCamPos = campos(guiH.viewAxis);
					camva(guiH.viewAxis,'manual');
				end
				
				cartesianToSpherical = @(XYZ) cell2mat(c_wrap(@() cart2sph(XYZ(1),XYZ(2),XYZ(3)),1:3));
				sphericalToCartesian = @(aer) cell2mat(c_wrap(@() sph2cart(aer(1),aer(2),aer(3)),1:3));
				
				newSph = cartesianToSpherical(XYZ-origin);
				oldSph = cartesianToSpherical(guiH.viewInteraction_startPos-origin);
				
				oldCamSph = cartesianToSpherical(guiH.viewInteraction_startCamPos - origin);
				newCamSph = oldCamSph;
				newCamSph(1:2) = oldCamSph(1:2) - (newSph(1:2)-oldSph(1:2));
				newCamSph(3) = oldCamSph(3) * (newSph(3)/oldSph(3));
				
				newCamPos = sphericalToCartesian(newCamSph) + origin;
				
				campos(guiH.viewAxis,newCamPos);
			end
			
			if s.doPlotControllerEndpoint
	% 			c_say('Redrawing controller endpoint')
				guiH.ControllerEndpointHandle = c_plot_scatter3(XYZ,...
					'axis',guiH.viewAxis,...
					'ptColors',[0 0 0],...
					'ptSizes',c_convertValuesFromUnitToUnit(3,'mm',s.distUnit));
	% 			c_sayDone();
			end
			
			if (s.doShowLiveDistFromTarget || s.doShowLiveDistFromPrevious) && ...
					~ismember(s.currentState,{'recordingFiducials','recordingElectrodes','recordingShapePts'})
					if s.doShowLiveDistFromTarget
						guiH.liveDistFromTarget.String = '';
					end
					if s.doShowLiveDistFromPrevious
						guiH.liveDistFromPrevious.String = '';
					end
			else
				otherXYZ = nan(1,3);
				if s.doShowLiveDistFromTarget
					switch(s.currentState)
						case 'recordingFiducials'
								i = s.currentStateVars.fiducialCounter;
								m = s.measuredMontage.fiducials;
								t = s.templateMontage.fiducials;
						case 'recordingElectrodes'
								i = s.currentStateVars.electrodeCounter;
								m = s.measuredMontage.electrodes;
								t = s.templateMontage.electrodes;
						case 'recordingShapePts'
								i = s.currentStateVars.shapePtCounter;
								m = s.measuredMontage.shapePoints;
								t = s.templateMontage.shapePoints;
						otherwise
							error('should not get here');
					end
					
					if ~c_isEmptyOrEmptyStruct(m) && length(m) >= i
						otherXYZ = c_convertValuesFromUnitToUnit(...
							c_struct_mapToArray(m(i),{'X','Y','Z'}),...
							s.measuredMontage.distUnit,s.distUnit);
					end
					if any(isnan(otherXYZ))
						% current point not in measured montage, check template as fallback
						if ~c_isEmptyOrEmptyStruct(t) && length(t) >= i
							otherXYZ = c_convertValuesFromUnitToUnit(...
								c_struct_mapToArray(t(i),{'X','Y','Z'}),...
								s.templateMontage.distUnit,s.distUnit);
						end
					end
					if ~any(isnan(otherXYZ))
						dist = c_norm(XYZ - otherXYZ,2);
						guiH.liveDistFromTarget.String = sprintf('%.2f mm',c_convertValuesFromUnitToUnit(dist,s.distUnit,'mm'));
					else
						guiH.liveDistFromTarget.String = '';
					end
				end
				if s.doShowLiveDistFromPrevious
					otherXYZ = s.previousXYZ;
					if ~any(isnan(otherXYZ))
						dist = c_norm(XYZ - otherXYZ,2);
						guiH.liveDistFromPrevious.String = sprintf('%.2f mm',c_convertValuesFromUnitToUnit(dist,s.distUnit,'mm'));
					else
						guiH.liveDistFromPrevious.String = '';
					end
				end
			end
		end
		
		if s.doSupportMultipleTrackers && s.doShowLiveMultitrackerAgreement
			if length(s.usedTrackerKeys) > 1
				whatToGet = 'XYZswrtTrackers';
				[XYZs, trackerKeys] = d.convertFromRawTo(whatToGet,msg);
				assert(isequal(trackerKeys,s.usedTrackerKeys));
				
				numTrackers = size(XYZs,1);
				if ~isempty(d.trackerTransforms)
					assert(size(d.trackerTransforms,3)==numTrackers);
					for iT = 1:numTrackers
						XYZs(iT,:,:) = c_pts_applyTransform(permute(XYZs(iT,:,:),[3 2 1]),'quaternion',d.trackerTransforms(:,:,iT))';
					end
				end
				meanXYZ = mean(XYZs,1);
				dists = c_norm(bsxfun(@minus,XYZs,meanXYZ),2,2);
				dists = c_convertValuesFromUnitToUnit(dists,d.distUnit,'mm');
				guiH.liveMultitrackerAgreement.String = sprintf('%s mm',c_toString(dists','precision',3));
			else
				guiH.liveMultitrackerAgreement.String = '';
			end
		end
		
		catch e
			if strcmpi(e.identifier,'MATLAB:class:InvalidHandle')
				% figure probably closed while we were redrawing
				% (do nothing)
			else
				c_say('Timer callback error: %s ''%s''',e.identifier,e.message);
				c_saySingleMultiline('%s',c_toString(e.stack));
				c_sayDone();
				rethrow(e);
			end
		end
	end
	
	%% Scalp mesh
	
	function callback_mesh_load(filepath)
		if ~strcmp(guiH.mesh_filefield.path,filepath)
			guiH.mesh_filefield.path = filepath;
		end
		if ~exist(filepath,'file')
			warning('File does not exist at %s',filepath);
			return;
		end
		c_say('Loading mesh from %s',filepath);
		s.mesh = c_mesh_load(filepath);
		c_sayDone();
		if ~c_mesh_isValid(s.mesh,'exhaustive',true)
			warning('Loaded mesh is invalid, discarding.');
			return;
		end
		s.mesh.isValidated = true;
	
		s.meshPath = guiH.mesh_filefield.path;
	
		if c_isFieldAndNonEmpty(s.mesh,'distUnit')
			s.meshDistUnit = s.mesh.distUnit;
		else
			s.mesh.distUnit = s.meshDistUnit;
		end
	
		s.mesh.origDistUnit = s.mesh.distUnit;
		s.mesh = c_mesh_convertToDistUnit(s.mesh,s.distUnit);
	
		callback_mesh_redraw();
	end
	
	function callback_mesh_redraw()
		if ~isempty(guiH.MeshHandle)
			delete(guiH.MeshHandle);
			guiH.MeshHandle = [];
		end
		if ~isempty(s.mesh) && s.doPlotHeadMesh
			c_saySingle('Redrawing mesh');
			guiH.MeshHandle = c_mesh_plot(s.mesh,...
				'view',[],...
				'faceColor',s.meshFaceColor,...
				'faceAlpha',s.meshFaceAlpha,...
				'axis',guiH.viewAxis);
		end
	end
	
	function callback_mesh_clear(~)
		c_saySingle('Clearing mesh');
		s.mesh = [];
		s.meshPath = '';
		callback_mesh_redraw();
	end
	
	%% template montage
	
	function callback_templateMontage_load(filepath)
		if ~strcmp(guiH.templateMontage_filefield.path,filepath)
			guiH.templateMontage_filefield.path = filepath;
		end
		if ~exist(filepath,'file')
			warning('File does not exist at %s',filepath);
			return;
		end
		c_say('Loading templateMontage from %s',filepath);
		s.templateMontage = c_DigitizedMontage('initFromFile',filepath);
		c_sayDone();
	
		s.templateMontagePath = guiH.templateMontage_filefield.path;
	
		callback_templateMontage_redraw();
		callback_table_redraw();
	end
	
	function callback_templateMontage_redraw()
		if ~isempty(guiH.TemplateMontageHandle)
			delete(guiH.TemplateMontageHandle);
			guiH.TemplateMontageHandle = [];
		end
		if ~isempty(s.templateMontage)
			c_saySingle('Redrawing template montage');
			guiH.TemplateMontageHandle = s.templateMontage.plot(...
				'axis',guiH.viewAxis,...
				'distUnit',s.distUnit,...
				'doPlotElectrodes',s.doPlotTemplateElectrodes,...
				'doPlotFiducials',s.doPlotTemplateFiducials,...
				'doPlotHeadshape',s.doPlotShapePts,...
				'doLabelElectrodes',s.doLabelTemplateElectrodes,...
				'doLabelFiducials',s.doLabelTemplateFiducials,...
				'colorElectrodes',[0.7 0.7 0.9],...
				'colorFiducials',[0.7 0.9 0.7],...
				'colorShapePts',[0.8 0.8 0.8],...
				'view',[]);
		end
	end
	
	function callback_templateMontage_clear(~)
		c_saySingle('Clearing templateMontage');
		s.templateMontage = [];
		s.templateMontagePath = '';
		callback_templateMontage_redraw();
		callback_table_redraw();
	end
	
	%% measured montage
	
    function [allFidLabels, indicesInTemplate, indicesInMeasured] = getCombinedFiducialList() 
        convertEmptyStructs = @(x) c_if(isstruct(x) && c_isEmptyStruct(x),[],x);
        if ~isempty(s.templateMontage)
			tFiducials = convertEmptyStructs(s.templateMontage.fiducials);
        else 
            tFiducials = [];
        end
        
        if ~isempty(s.measuredMontage)
			mFiducials = convertEmptyStructs(s.measuredMontage.fiducials);
        else
            mFiducials = [];
        end
        
        allFidLabels = {};
		numCommonFiducials = 0;
		if ~isempty(tFiducials) && ~isempty(mFiducials)
			for iF = 1:min(length(tFiducials),length(mFiducials))
				if isequal(tFiducials(iF).label,mFiducials(iF).label)
					numCommonFiducials = numCommonFiducials+1;
				else
					break;
				end
			end
			allFidLabels = [allFidLabels, {tFiducials(1:numCommonFiducials).label}];
        end
        
		if ~isempty(tFiducials)
			allFidLabels = [allFidLabels, {tFiducials(numCommonFiducials+1:end).label}];
		end
		if ~isempty(mFiducials)
			allFidLabels = [allFidLabels, {mFiducials(numCommonFiducials+1:end).label}];
		end
		
		if c_isFieldAndNonEmpty(s,'currentStateVars.fiducialCounter')
			iF = s.currentStateVars.fiducialCounter;
		else
			iF = [];
		end
		if ~isempty(iF) && iF > length(allFidLabels)
			% could be made more efficient...
			for iiF = (length(allFidLabels)+1):iF
				allFidLabels{iiF} = getNthFiducialLabel(allFidLabels,iiF);
			end
		end
    
        indicesInTemplate = nan(size(allFidLabels));
        indicesInMeasured = nan(size(allFidLabels));
        
        indicesInTemplate(1:length(tFiducials)) = 1:length(tFiducials);
        indicesInMeasured(1:numCommonFiducials) = 1:numCommonFiducials;
        indicesInMeasured(length(tFiducials)+(1:length(mFiducials)-numCommonFiducials)) = numCommonFiducials + (1:length(mFiducials)-numCommonFiducials);
	end

	function fidLabel = getNthFiducialLabel(fiducialLabels, n)
		if n <= length(fiducialLabels)
			fidLabel = fiducialLabels{n};
		else
			uniqueFiducialLabels = unique(fiducialLabels,'stable');
			fidLabel = uniqueFiducialLabels{mod(n-1,length(uniqueFiducialLabels))+1};
		end
	end
    
	function callback_measuredMontage_initEmpty()
		s.measuredMontage = c_DigitizedMontage('distUnit',s.distUnit);
		
		if s.doSupportMultipleTrackers
			for iT = 1:length(s.trackerKeys)
				s.([s.trackerKeys{iT} '_measuredMontage']) = c_DigitizedMontage('distUnit',s.distUnit);
			end
		end
		
		s.measuredMontageUnsaved = false;
		
		callback_measuredMontage_redraw();
		callback_table_redraw();
	end
	
	function callback_measuredMontage_load(filepath)
		if ~isempty(s.measuredMontage) && ...
				~GUI_verify('Are you sure you want to clear measured montage?',false)
			return; % cancelled
		end
	
		if ~strcmp(guiH.measuredMontage_filefield.path,filepath)
			guiH.measuredMontage_filefield.path = filepath;
		end
		if ~exist(filepath,'file')
			warning('File does not exist at %s',filepath);
			return;
		end
		c_say('Loading measuredMontage from %s',filepath);
		s.measuredMontage = c_DigitizedMontage('initFromFile',filepath);
		c_sayDone();
		
		if s.doSupportMultipleTrackers
			for iT = 1:length(s.trackerKeys)
				s.([s.trackerKeys{iT} '_measuredMontage']) = c_DigitizedMontage('distUnit',s.distUnit);
			end
		end
	
		s.measuredMontageUnsaved = false;
		
		s.measuredMontagePath = filepath;
	
		callback_measuredMontage_redraw();
		callback_table_redraw();
	end
	
	function callback_measuredMontage_save(filepath)
		if nargin==0
			guiH.measuredMontage_filefield.simulateButtonPress('save to...');
			return;
		end
		if isempty(s.measuredMontage)
			GUIError('Cannot save empty montage');
		end
		c_say('Saving measured montage to %s',filepath);
		s.measuredMontage.saveToFile(filepath);
		c_sayDone();
		
		s.measuredMontageUnsaved = false;
	end
	
	
	function callback_measuredMontage_redraw()
		if ~isempty(guiH.MeasuredMontageHandle)
			delete(guiH.MeasuredMontageHandle);
			guiH.MeasuredMontageHandle = [];
		end
		if ~isempty(s.templateMontage)
			guiH.MeasuredMontageHandle = s.measuredMontage.plot(...
				'axis',guiH.viewAxis,...
				'distUnit',s.distUnit,...
				'doPlotFiducials',s.doPlotFiducials,...
				'doPlotElectrodes',s.doPlotElectrodes,...
				'doPlotHeadshape',s.doPlotShapePts,...
				'doLabelElectrodes',s.doLabelElectrodes,...
				'doLabelFiducials',s.doLabelFiducials,...
				'view',[]);
		end
	end
	
	function callback_measuredMontage_clear(~)
		if ~GUI_verify('Are you sure you want to clear measured montage?',false)
			return; % cancelled
		end
		
		s.measuredMontageUnsaved = false;
	
		c_saySingle('Clearing measuredMontage');
		callback_measuredMontage_initEmpty();
		callback_measuredMontage_redraw();
		callback_table_redraw();
	end
	
	function didFail = callback_measuredMontage_processFiducials()
		% estimate transform from measurement space to output (template) space
	
		% assume that if called, fiducial measurements are complete
		assert(s.measuredMontage.numFiducials >= 3); % need at least 3 fiducials for estimating transform
	
		didFail = false;
		
		% require fiducials to be defined in template montage for alignment
		assert(s.templateMontage.numFiducials<=s.measuredMontage.numFiducials);

		aligningTransform = s.measuredMontage.alignTo(s.templateMontage,...
			'method','fiducials',...
			'doApplyTransform',false);
		aligningTransform = transfConvertDistUnits(aligningTransform,s.measuredMontage.distUnit,s.distUnit);

		s.measuredMontage.transform(aligningTransform,...
			'doApplyToFiducials',true,...
			'doApplyToElectrodes',false,...
			'doApplyToShapePoints',false,...
			'distUnit',s.distUnit);
		
		s.previousXYZ = c_pts_applyTransform(s.previousXYZ,'quaternion',aligningTransform);
		
		if ~isempty(s.measurementTransform)
			% assume if a previous transform was set, it was already applied to the measured fiducials
			% so combine it with the new transform to get a complete transform from original space
			aligningTransform = aligningTransform*s.measurementTransform;
		end
		
		invAligningTransform = pinv(aligningTransform);
		
		s.measurementTransform = aligningTransform;
		
		if s.doSupportMultipleTrackers 

			trackerAligningTransforms = nan(4,4,length(s.usedTrackerKeys));

			for iT = 1:length(s.usedTrackerKeys)
				% start by calculating transforms to convert from each independent tracker space to calibrated fiducial space
				trackerAligningTransforms(:,:,iT) = s.([s.usedTrackerKeys{iT} '_measuredMontage']).alignTo(s.templateMontage,...
					'method','fiducials',...
					'doApplyTransform',false);
				trackerAligningTransforms(:,:,iT) = transfConvertDistUnits(trackerAligningTransforms(:,:,iT),...
					s.([s.trackerKeys{iT} '_measuredMontage']).distUnit,s.distUnit);

				% then convert these all to transform to space of first tracker instead (to then be able to apply same universal measurement transform to all)
				trackerAligningTransforms(:,:,iT) = invAligningTransform*trackerAligningTransforms(:,:,iT);
				% (here, trackerAligningTransforms(:,:,1) should be approximately or exactly identity)

				if 1
					% to double check, calculate residuals to see whether trackers agree on relative fiducial positions
					mainXYZs = s.measuredMontage.getFiducialsAsXYZ('distUnit',s.distUnit);
					otherXYZs = s.([s.usedTrackerKeys{iT} '_measuredMontage']).getFiducialsAsXYZ('distUnit',s.distUnit);
					otherXYZs = c_pts_applyTransform(otherXYZs,'quaternion',aligningTransform*trackerAligningTransforms(:,:,iT));
					residuals = c_norm(mainXYZs - otherXYZs,2,2)
					if any(residuals > c_convertValuesFromUnitToUnit(2,'mm',s.distUnit))
						if GUI_verify(sprintf('Tracker %s does not agree on fiducial positions. Continue anyways?\n (Select No to remeasure fiducials)',...
								s.usedTrackerKeys{iT}))
							% continue
						else
							% do not continue
							% instead, restart fiducial measurements
							didFail = true;
							return;
						end
					end
				end

				assert(isequal(s.usedTrackerKeys,d.trackerKeys));
			end

			d.trackerTransforms = trackerAligningTransforms;
		end
	
		if s.doSupportMultipleTrackers && ~isempty(s.usedTrackerKeys)
			s.trackerTransforms = trackerAligningTransforms;
			
			if ~isempty(d)
				d.trackerTransforms = transfConvertDistUnits(s.trackerTransforms,s.distUnit,d.distUnit);
			end
		end
	
		c_say('Estimated measurement transform:')
		c_saySingleMultiline(c_toString(s.measurementTransform,'doPreferMultiline',true));
		c_sayDone();
	
		s.measuredMontageUnsaved = true;
		
		callback_measuredMontage_redraw();
		callback_table_redraw();
	end
	
	%% persistent settings
	function callback_persistentSettings_load(filepath)
		if ~exist(filepath,'file')
			warning('File does not exist at %s',filepath);
			return
		end
		tmp = load(filepath);
	
		c_say('Loading saved settings from %s',filepath);
	
		fields = s.persistentSettingsFields;
		for iF = 1:length(fields)
			if isfield(tmp,fields)
				if ~isequal(s.(fields{iF}),tmp.(fields{iF}))
					c_saySingle('Saved setting for %s overriding default',fields{iF});
					s.(fields{iF}) = tmp.(fields{iF});
				end
			end
		end
		
		c_sayDone();
	end
	
	function callback_persistentSettings_save(filepath)
		if nargin == 0
			filepath = s.persistentSettingsPath;
		end
		
		fields = s.persistentSettingsFields;
		toSave = struct();
		for iF = 1:length(fields)
			if ~isfield(s,fields{iF})
				warning('%s is not a valid setting',fields{iF});
			else
				toSave.(fields{iF}) = s.(fields{iF});
			end
		end
		c_saySingle('Saving persistent settings to %s',filepath);
		save(filepath,'-struct','toSave');
	end
	
	%% misc
	function speak(str,varargin)
		if s.doSpeak && ispc
			guiH.tts.say(str,varargin{:});
		end
	end
	
	function speakVerbose(str,varargin)
		if s.doSpeakVerbose && ispc
			guiH.tts.say(str,varargin{:});
		end
	end

	function callback_startViewInteraction()
		guiH.viewInteraction_prev_doPlotControllerEndpoint = s.doPlotControllerEndpoint;
		s.doPlotControllerEndpoint = true;
		
		guiH.viewInteraction_isOngoing = true;
		
		guiH.viewInteraction_startPos = [];
		guiH.viewInteraction_startCamPos = [];
	end

	function callback_stopViewInteraction()
		if ~c_isFieldAndNonEmpty(guiH,'viewInteraction_prev_doPlotControllerEndpoint')
			error('Was start view interaction called before this?');
		end
		s.doPlotControllerEndpoint = guiH.viewInteraction_prev_doPlotControllerEndpoint;
		
		guiH.viewInteraction_isOngoing = false;
	end
	
	%% debug 

	function callback_keyboard()
		keyboard
	end
	
	function XYZ = getDataCursorXYZ()
	
		dcm_obj = datacursormode(guiH.fig);
		info_struct = getCursorInfo(dcm_obj);
		dcm_obj.Enable = 'off';
		if isempty(info_struct)
			warning('No point selected');
			XYZ = [];
			return;
		end
		XYZ = info_struct.Position;
	
	end
	
	%%
	function callback_triggerMeasurement()
		if ~isempty(d) && d.isConnected()
			if strcmp(s.currentState,'calibratingDigitizer')
				whatToGet = 'XYZUncorrected';
			elseif strcmp(s.currentState,'recordingFiducials')
				if ~isempty(s.usedTrackerKeys)
					whatToGet = {'XYZ','pointer',s.usedTrackerKeys{1}};
				else
					whatToGet = 'XYZ';
				end
			else
				if ~isempty(s.usedTrackerKeys) 
					if s.doSupportMultipleTrackers
						whatToGet = 'XYZwrtTrackers';
					else
						whatToGet = {'XYZ','pointer',s.usedTrackerKeys{1}};
					end
				else
					whatToGet = 'XYZ';
				end
			end
			if s.doRequireStableSample
				%c_saySingle('whatToGet: %s',c_toString(whatToGet));
				XYZ = d.getStable(whatToGet,...
					'distTolerance',c_convertValuesFromUnitToUnit(s.stableSampleDistThreshold,s.distUnit,d.distUnit));
				if isempty(XYZ)
					%warning('Measurement timed out before becoming stable');
					return;
				end
			else
				XYZ = d.getMostRecent(whatToGet);
			end
			% assume if we blocked for stable measurement above, this most recent raw measurement is also roughly stable
			rawMeasurement = d.getMostRecent('RawMeasurement'); 
			
			XYZ = c_convertValuesFromUnitToUnit(XYZ,s.vr_distUnit,s.distUnit);
		else
			XYZ = getDataCursorXYZ();
			if isempty(XYZ)
				ip = c_InputParser();
				ip.addParameter('X',0,@isscalar);
				ip.addParameter('Y',0,@isscalar);
				ip.addParameter('Z',0,@isscalar);
				ip.parseFromDialog();
				XYZ = c_struct_mapToArray(ip.Results,{'X','Y','Z'});
			end
			rawMeasurement = [];
		end
		if isempty(XYZ)
			warning('No measurement available');
			return;
		end
		callback_processNewMeasurement(XYZ,rawMeasurement);
	end

	function callback_clearMeasurement()
		callback_processNewMeasurement([],[]);
	end
	
	%%
	function resp = GUI_verify(msg,defaultIsYes)
		if nargin < 2 || defaultIsYes
			default = 'Yes';
		else
			default = 'No';
		end
		resp = GUI_dialog(msg,...
			'responses',{'No','Yes'},...
			'default',default,...
			'doReturnLogical',true);
	end
	
	function resp = GUI_dialog(varargin)
		ip = inputParser();
		ip.addRequired('msg',@ischar);
		ip.addParameter('responses',{'No','Yes'},@iscell);
		ip.addParameter('default','Yes',@ischar);
		ip.addParameter('doReturnLogical','auto',@islogical);
		ip.parse(varargin{:});
		is = ip.Results;
	
		if strcmpi(is.doReturnLogical,'auto')
			is.doReturnLogical = ismember('responses',ip.UsingDefaults);
		end
		
		speakVerbose(is.msg);
	
		dlg = c_GUI_Dialog(is.msg,...
			'buttons',is.responses,...
			'default',is.default,...
			'doReturnLogical',is.doReturnLogical);
	
		args = {'doNonBlockingCallbacks',false};
	
		switch(length(is.responses))
			case 1
				callback_mainButtons_pushConfigToStack(args{:},...
					'right',{is.responses{1},@(~,~) dlg.buttonPressed(1)});
			case 2
				callback_mainButtons_pushConfigToStack(args{:},...
					'left',	{is.responses{1},@(~,~) dlg.buttonPressed(1)},...
					'right',{is.responses{2},@(~,~) dlg.buttonPressed(2)});
			case 3
				callback_mainButtons_pushConfigToStack(args{:},...
					'left',	{is.responses{1},@(~,~) dlg.buttonPressed(1)},...
					'down',	{is.responses{2},@(~,~) dlg.buttonPressed(2)},...
					'right',{is.responses{3},@(~,~) dlg.buttonPressed(3)});
			case 4
				callback_mainButtons_pushConfigToStack(args{:},...
					'left',	{is.responses{1},@(~,~) dlg.buttonPressed(1)},...
					'up',	{is.responses{2},@(~,~) dlg.buttonPressed(2)},...
					'down',	{is.responses{3},@(~,~) dlg.buttonPressed(3)},...
					'right',{is.responses{4},@(~,~) dlg.buttonPressed(4)});
			otherwise
				keyboard %TODO
		end
		resp = dlg.show();
		callback_mainButtons_popConfigFromStack();
	end

	function GUIError(varargin)
		if ~isempty(d) && d.isConnected()
			d.sendFeedback('audioTone','error');
		end

		str = sprintf(varargin{:});
		resp = questdlg(sprintf('Error:\n%s',str),'Error','Stop','Stop');
		if strcmpi(resp,'Stop')
			error(varargin{:});
		else
			warning(varargin{:});
			keyboard
		end
	end
end

function transf = transfConvertDistUnits(transf,fromUnits,toUnits)
	transf(1:3,4,:) = c_convertValuesFromUnitToUnit(transf(1:3,4,:),fromUnits,toUnits);
end
	
function str = prettifyTrackedDeviceStr(str)
	if strcmpi(str,'HMD')
		str = 'HMD';
	end
	numericIndices = ismember(str,'0':'9');
	numericIndices = find(numericIndices & [false diff(numericIndices) > 0]);
	for i=length(numericIndices):-1:1
		str = [str(1:numericIndices(i)-1) ' ' str(numericIndices(i):end)];
	end
end
	
	
