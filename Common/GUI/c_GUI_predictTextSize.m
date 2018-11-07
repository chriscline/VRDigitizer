function sz = c_GUI_predictTextSize(varargin)
p = inputParser;
p.addRequired('string',@ischar);
p.addParameter('FontSize',[],@isscalar);
p.addParameter('Parent',[],@ishandle);
p.addParameter('Units','pixels',@ischar);
p.parse(varargin{:});
s = p.Results;

args = {'Style','text',...
	'String',s.string,...
	'Units',s.Units,...
	'Visible','off'};

if ~isempty(s.FontSize)
	args = [args, 'FontSize',s.FontSize];
end

if ~isempty(s.Parent)
	args{end+1} = 'Parent';
	args{end+1} = s.Parent;
end

ht = uicontrol(args{:});

sz = ht.Extent(3:4);

delete(ht);

end