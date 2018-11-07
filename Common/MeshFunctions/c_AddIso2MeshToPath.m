function c_AddIso2MeshToPath()
persistent pathModified;
if isempty(pathModified)
	mfilepath=fileparts(which(mfilename));
	addpath(fullfile(mfilepath,'../ThirdParty/iso2mesh'));
	pathModified = true;
end
end