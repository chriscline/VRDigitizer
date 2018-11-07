function colors = c_getColors(n_colors,varargin)
% c_getColors - wrapper around third-party distinguishable_colors()
%
% Example:
%	figure; c_plot_scatter3(rand(10,3),'ptColors',c_getColors(10))

persistent PathModified;
if isempty(PathModified)
	mfilepath=fileparts(which(mfilename));
	addpath(fullfile(mfilepath,'./ThirdParty/distinguishable_colors'));
	PathModified = true;
end

colors = distinguishable_colors(n_colors,varargin{:});

end