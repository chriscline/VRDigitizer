function c_mesh_AddGIfTILibToPath()
	persistent pathModified;
	if isempty(pathModified)
		mfilepath=fileparts(which(mfilename));
		addpath(fullfile(mfilepath,'../ThirdParty/gifti'));
		pathModified = true;
	end
end