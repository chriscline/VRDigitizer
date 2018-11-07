classdef c_GUI_EditField < c_GUI_handle
% c_GUI_EditField - GUI class to draw an editable text field with an optional label
% Allows adding a real-time validator to the text field and setting up value change callbacks, etc.

	properties
		Units
		Position
		Callback
		ValueToStringConverter
		ValueOutputConverter
		ValueOutputValidator
	end
	
	properties(Dependent)
		String
		Value
		FontAngle
		BackgroundColor
	end
	
	properties(SetAccess=protected)
		Parent
		Label %TODO: must be able to dynamically resize if allowing non-constructor setting of label
		doLiveValidation
		doShowLiveValidationOnlyOnFocus
		defaultBackgroundColor;
		isReadOnly;
	end
	
	properties(Access=protected)
		gcont
		hEdit
	end
	
	
	methods
		function o = c_GUI_EditField(varargin)
			if nargin == 0, c_GUI_EditField.testfn(); return; end;
			p = inputParser();
			p.addParameter('Position',[0 0 1 1],@isvector);
			p.addParameter('Units','normalized',@ischar);
			p.addParameter('Parent',[],@ishandle);
			p.addParameter('String','',@ischar);
			p.addParameter('Value',[]);
			p.addParameter('ValueToStringConverter',@c_toString,@(x) isa(x,'function_handle'));
			p.addParameter('ValueOutputConverter',[],@(x) isa(x,'function_handle'));
			p.addParameter('ValueOutputValidator',[],@(x) isa(x,'function_handle'));
			p.addParameter('doLiveValidation',true,@islogical);
			p.addParameter('doShowLiveValidationOnlyOnFocus',true,@islogical);
			p.addParameter('Callback',[],@(x) isa(x,'function_handle'));
			p.addParameter('Label','',@ischar);
			p.addParameter('LabelPosition','left',@(x) ismember(x,{'left','above'}));
			p.addParameter('LabelWidth',[],@isscalar);
			p.addParameter('defaultBackgroundColor',[1 1 1],@isvector);
			p.addParameter('isReadOnly',false,@islogical);
			p.parse(varargin{:});
			s = p.Results;
			
			% assume each parser parameter has property with identical name
			for iF = 1:length(p.Parameters)
				if ismember(p.Parameters{iF},{'String','Value'})
					continue; % skip some parameters
				end
				if isprop(o,p.Parameters{iF})
					o.(p.Parameters{iF}) = s.(p.Parameters{iF});
				end
			end
			
			if all(~ismember({'String','Value'},p.UsingDefaults))
				error('Only one of String and Value should be specified');
			end
			
			% construct GUI
			switch(s.LabelPosition)
				case 'left'
					hhb = uix.HBox('Parent',o.Parent,'Spacing',5);
					
					if 1
						ht = c_GUI_Text(...
							'Parent',hhb,...
							'String',o.Label,...
							'HorizontalAlignment','right',...
							'doAutoResize',~isempty(s.LabelWidth)...
							);
						ht.setVerticalAlignment(javax.swing.JLabel.CENTER);
					else
						ht = uicontrol('style','Text',...
							'HorizontalAlignment','right',...
							'Parent',hhb,...
							'String',o.Label);
						if 0
							jh = findjobj(ht);
							jh.setVerticalAlignment(javax.swing.JLabel.CENTER)
						else
							% run after delay to reduce drawnow time in findjobj
							c_fn_runAfterDelay(@(th) c_use(...
								findjobj(th),...
									@(jh) jh.setVerticalAlignment(javax.swing.JLabel.CENTER)),...
									1,...
								'args',{o.th})
						end
					end
					
					if isempty(s.LabelWidth)
						sz = c_GUI_predictTextSize(s.Label,'Parent',hhb);
						s.LabelWidth = sz(1);
					end
					
					o.hEdit = uicontrol('style','Edit',...
						'Parent',hhb,...
						'String',s.String,...
						'Enable',c_if(s.isReadOnly,'off','on'),...
						'BackgroundColor',s.defaultBackgroundColor,...
						'Callback',@o.editCallback);
					
					if s.doLiveValidation
						hfj = handle(java(findjobj(o.hEdit)),'CallbackProperties');
						set(hfj,'KeyPressedCallback',@(h,e) o.revalidateField(h,e));
						set(hfj,'FocusGainedCallback',@(h,e) o.fieldGainedFocus(h,e));
						set(hfj,'FocusLostCallback',@(h,e) o.fieldLostFocus(h,e));
					end
					
					set(hhb,'Widths',[s.LabelWidth, -1]);
					
				case 'above'
					keyboard %TODO
					
				otherwise
					error('Invalid LabelPosition: %s',s.LabelPosition);
			end
			
			if ~ismember('Value',p.UsingDefaults)
				o.Value = s.Value;
			end
		end
		
		function set.String(o,newStr) 
			assert(ischar(newStr));
			o.hEdit.String = newStr;
		end
		
		function str = get.String(o)
			str = o.hEdit.String;
		end
		
		function set.Value(o,newVal)
			o.String = o.ValueToStringConverter(newVal);
		end
		
		function [val, isValid] = getValueIfValid(o)
			try
				val = o.Value;
				isValid = true;
			catch
				val = [];
				isValid = false;
			end
		end
		
		function val = get.Value(o)
			val = o.convertStringToValue(o.String);
		end
		
		function val = get.FontAngle(o)
			val = o.hEdit.FontAngle;
		end
		function set.FontAngle(o,val)
			o.hEdit.FontAngle = val;
		end
		
		function val = get.BackgroundColor(o)
			val = o.hEdit.BackgroundColor;
		end
		function set.BackgroundColor(o,val)
			o.defaultBackgroundColor = val;
			o.hEdit.BackgroundColor = val;
		end
	end
	
	methods(Access=protected)
		function val = convertStringToValue(o,str)
			try
				val = eval(str);
			catch
				error('Problem converting string to value: ''%s''',str);
			end
			%c_saySingle('val: %s',c_toString(val));
			if ~isempty(o.ValueOutputConverter)
				val = o.ValueOutputConverter(val);
				%c_saySingle('Converted val: %s',c_toString(val));
			end
			if ~isempty(o.ValueOutputValidator)
				assert(o.ValueOutputValidator(val));
				%c_saySingle('Val is valid');
			end
		end
		
		function fieldGainedFocus(o,h,e)
			o.revalidateField(h,e);
		end
		
		function fieldLostFocus(o,h,e)
			if ~isgraphics(o.hEdit)
				% object invalid/deleted
				return;
			end
			if o.doShowLiveValidationOnlyOnFocus
				o.hEdit.BackgroundColor = o.defaultBackgroundColor;
			end
		end
		
		function revalidateField(o,h,e)
			assert(o.doLiveValidation);
			
			if isempty(o.ValueOutputConverter) && isempty(o.ValueOutputValidator)
				return;
			end
			
			if isprop(h,'String') || isfield(h,'String')
				str = h.String;
			else
				% java callback
				str = char(h.getText);
			end
			try
				val = o.convertStringToValue(str);
				isValid = true;
						catch
				isValid = false;
			end

			if isValid
				o.hEdit.BackgroundColor = [0.4 1 0.4];
			else
				o.hEdit.BackgroundColor = [1 0.4 0.4];
			end
		end
		
		function editCallback(o,h,e)
			if ~isempty(o.Callback)
				o.Callback(o,e);
			end
		end
	end
	
	methods(Static)
		function addDependencies()
			persistent pathModified;
			if isempty(pathModified)
				mfilepath=fileparts(which(mfilename));
				addpath(fullfile(mfilepath,'../ThirdParty/findjobj'));
				addpath(fullfile(mfilepath,'../'));
				c_GUI_initializeGUILayoutToolbox();
				pathModified = true;
			end
		end
		
		function testfn()
			c_GUI_EditField.addDependencies();
			hf = figure('Visible','off');
			hp = c_GUI_uix_VBox('parent',hf,'spacing',5);
			hp.add(@(parent)...
				c_GUI_EditField('Parent',parent,...
					'Label','Unvalidated string:',...
					'String','A string'),...
				'height',20);
			hp.add(@(parent)...
				c_GUI_EditField('Parent',parent,...
					'Label','Validated string:',...
					'Value','A string value',...
					'ValueOutputValidator',@ischar),...
				'height',20);
			hp.add(@(parent)...
				c_GUI_EditField('Parent',parent,...
					'Label','Vector:',...
					'Value',[1 2 3],...
					'ValueOutputValidator',@isvector),...
				'height',20);
			hp.add(@(parent)...
				c_GUI_EditField('Parent',parent,...
					'Label','Cell:',...
					'Value',{'hello',[1 2]},...
					'ValueOutputValidator',@iscell),...
				'height',20);
			hf.Visible = 'on';
		end
	end
end
	