classdef c_GUI_Dialog < handle
% c_GUI_Dialog - GUI class to present a standalone dialog window to the user

	properties
		msg;
		title;
		buttons;
		default;
		doReturnLogical;
		size;
		buttonHeight;
		spacing;
		timeout;
	end
	
	properties(Access=protected)
		buttonPressedIndex = [];
		hf = [];
	end
	
	methods
		function o = c_GUI_Dialog(varargin)
			p = inputParser();
			p.addRequired('msg',@ischar);
			p.addParameter('title','',@ischar);
			p.addParameter('buttons',{'No','Yes'});
			p.addParameter('default','Yes',@ischar);
			p.addParameter('doReturnLogical','auto',@islogical);
			p.addParameter('size',[350 70],@isvector);
			p.addParameter('buttonHeight',40,@isscalar);
			p.addParameter('spacing',10,@isscalar);
			p.addParameter('timeout',inf,@isscalar); % in s
			p.parse(varargin{:});
			s = p.Results;
			
			if strcmpi(s.doReturnLogical,'auto')
				s.doReturnLogical = ismember('buttons',p.UsingDefaults);
			end
			
			if ismember('title',p.UsingDefaults)
				s.title = 'Dialog';
			end
			
			% copy parsed input to object properties of the same name
			fieldNames = fieldnames(s);
			for iF=1:length(fieldNames)
				if isprop(o,p.Parameters{iF})
					o.(fieldNames{iF}) = s.(fieldNames{iF});
				end
			end
		end
		
		function resp = show(o)
			
			
			numLines = 1+length(strfind(o.title,sprintf('\n')));
			textHeight = 20*numLines;
			
			menuHeight = 0;
			
			height = menuHeight + o.spacing + textHeight + o.spacing + (o.buttonHeight+o.spacing)*1;
			
			o.hf = figure(...
				'Position',[0 0 o.size(1) height],...
				'MenuBar','None',...
				'KeyPressFcn',@(h,e) o.keyPressed(h,e),...
				'CloseRequestFcn',@(h,e) o.closeDlg(),...
				'Name',o.title);
			
			movegui(o.hf,'center');
			drawnow();
			
			uicontrol('Parent',o.hf,...
				'Style','text',...
				'Units','Pixels',...
				'Position',[o.spacing, height - menuHeight - o.spacing - textHeight, o.size(1) - 2*o.spacing, textHeight],...
				'HorizontalAlignment','left',...
				'String',o.msg);
			
			numButtons = length(o.buttons);
			buttonWidth = (o.size(1) - o.spacing*(numButtons+1))/numButtons;
			buttonYPos = height - menuHeight - o.spacing - textHeight - o.spacing - o.buttonHeight;
			for iB = 1:numButtons
				hb = uicontrol('Parent',o.hf,...
					'Style','pushbutton',...
					'Position',[o.spacing*iB + buttonWidth*(iB-1), buttonYPos, buttonWidth, o.buttonHeight],...
					'Callback',@(h,e) o.buttonPressed(iB),...
					'String',o.buttons{iB});
				if isequal(o.buttons{iB},o.default)
					hb.Value = 1; % http://undocumentedmatlab.com/blog/undocumented-button-highlighting
				end
			end
			
			c_say('Waiting for user input: %s',o.msg);
			c_waitfor(o,'buttonPressedIndex','timeout',o.timeout);

			assert(~isempty(o.buttonPressedIndex));
			
			if o.buttonPressedIndex == 0
				% dialog canceled without pressing a button
				if o.doReturnLogical
					resp = false;
				else
					resp = '';
				end
				c_saySingle('Dialog cancelled');
			else
				if o.doReturnLogical
					resp = o.buttonPressedIndex > 1;
				else
					resp = o.buttons{o.buttonPressedIndex};
				end
				c_saySingle('User responded: ''%s''',o.buttons{o.buttonPressedIndex});
			end
			
			c_sayDone();
			
			o.closeDlg;
		end
		
		function closeDlg(o)
			o.buttonPressed(0);
			if ishandle(o.hf)
				delete(o.hf);	
			end
		end
		
		function buttonPressed(o,btn)
			% btn can be index into buttons or string
			if ischar(btn)
				index = find(ismember(btn,o.buttons),1,'first');
				if isempty(index)
					error('''%s'' does not match any buttons');
				end
				btn = index;
			end
			
			o.buttonPressedIndex = btn;
		end
		
		function keyPressed(o,h,e)
			btnIndex = [];
			if strcmpi(e.Key,'escape')
				btnIndex = 0;
			elseif strcmpi(e.Key,'return')
				btnIndex = find(ismember(o.buttons,o.default),1,'first');
				if isempty(btnIndex), btnIndex = 0; end;
			end
			if ~isempty(btnIndex)
				o.buttonPressed(btnIndex);
			end
		end
	end
end

function c_waitfor(varargin)
	p = inputParser();
	p.addRequired('h',@isvalid);
	p.addOptional('propName','',@ischar);
	p.addOptional('propVal',[]);
	p.addParameter('timeout',inf,@isscalar); % in s
	p.parse(varargin{:});
	s = p.Results;
	
	if ~ismember('propVal',p.UsingDefaults)
		keyboard %TODO: implement propval in same way as used by waitfor()
	end
	
	origValue = s.h.(s.propName);
	while isvalid(s.h) && isequal(s.h.(s.propName),origValue)
		pause(0.01);
	end
end