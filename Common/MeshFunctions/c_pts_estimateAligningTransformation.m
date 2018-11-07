function [estimatedTransform, movedPts] = c_pts_estimateAligningTransformation(varargin)
% c_pts_estimateAligningTransformation - estimate spatial transform to align two sets of points

if nargin==0, testfn(); return; end;

p = inputParser();
p.addParameter('stationaryPts',[],@ismatrix);
p.addParameter('movingPts',[],@ismatrix);
p.addParameter('doRigid',true,@islogical);
p.addParameter('numdim',3,@isscalar);
p.addParameter('method','svd',@ischar);
p.addParameter('doPlot',false,@islogical);
p.parse(varargin{:});
s = p.Results;

assert(s.numdim==3); % for now, only 3D is supported
assert(~isempty(s.stationaryPts));
assert(~isempty(s.movingPts));
assert(size(s.stationaryPts,2)==s.numdim);
assert(size(s.movingPts,2)==3);
assert(size(s.stationaryPts,1)==size(s.movingPts,1)); % for now, require that both point sets have the same number of points

persistent icpOnPath;

switch(s.method)
	case 'icp'		
		if isempty(icpOnPath)
			mfilepath=fileparts(which(mfilename));
			addpath(fullfile(mfilepath,'../ThirdParty/icp'));
			icpOnPath = true;
		end
		
		[TR, TT] = icp(s.stationaryPts', s.movingPts');
		
		estimatedTransform = cat(1,cat(2,TR,TT),[0 0 0 1]);
		
		warning('This method may not work correctly');
		%TODO: test more thoroughly
		
	case 'svd'
		% this method assumes point to point correspondence (i.e. that pt 1 in movingPts corresponds to pt 1 in stationaryPts)
		[TR, TT] = rigid_transform_3D_SVD(s.movingPts,s.stationaryPts);
		
		estimatedTransform = cat(1,cat(2,TR,TT),[0 0 0 1]);
		
	case 'fmincon'
		% this method assumes point to point correspondence
		
		% instead of directly optimizing 4x4 transform coefficients, work with feature space that only allows rigid transformation
		
		if 0
			optimVarsToTransf = @(xyzRot) c_calculateTransformationMatrixFromXYZAndEulerAngles(xyzRot(1:3),xyzRot(4:6));
		
			% initial guess
			optimVars = zeros(1,6);
			optimVars(1:3) = mean(s.movingPts,1) - mean(s.stationaryPts,1); %TODO: check sign

			% optimization constraints
			lb = [-inf -inf -inf -180 -180 -180];
			ub = [ inf  inf  inf  180  180  180];
			nonlincon = [];
		else
			% to avoid gimbal lock issues, use unit quaternions for rotation instead of something like Euler angles
			optimVarsToTransf = @(XYZQuat) c_calculateTransformationMatrixFromXYZAndQuaternion(...
				XYZQuat(1:3),XYZQuat(4:7)/c_norm(XYZQuat(4:7),2)); % note that quaternion is normalized here
		
			% initial guess
			optimVars = zeros(1,7);
			optimVars(7) = 1;
			optimVars(1:3) = mean(s.movingPts,1) - mean(s.stationaryPts,1); %TODO: check sign

			% optimization constraints
			if 1
				minDisp = -inf;
				maxDisp = inf;
			else
				maxDisp = (max(abs(s.movingPts(:))) + max(abs(s.stationaryPts(:))))*2; % could use smaller range to make more efficient
				minDisp = -maxDisp;
			end
			lb = [minDisp minDisp minDisp -1 -1 -1 -1];
			ub = [ maxDisp maxDisp maxDisp 1  1  1  1];
			nonlincon = @(xyzQuat) deal(0, sqrt(sum(optimVars(4:7).^2))-1);
			
		end
		
		costFn = @(optimVars) ...
				c_norm(...
					c_norm(bsxfun(@minus,...
						s.stationaryPts,...
						c_pts_applyTransform(s.movingPts,...
							'quaternion',optimVarsToTransf(optimVars))),...
						2,2),...
					'2sq');
				
		optimVars = fmincon(costFn,optimVars,[],[],[],[],lb,ub,nonlincon,...
			optimoptions('fmincon','Display','none'));
			
		estimatedTransform = optimVarsToTransf(optimVars);
		
	otherwise
		error('Invalid method: %s',s.method);
end

if nargout > 1 || s.doPlot
	movedPts = c_pts_applyRigidTransformation(s.movingPts,estimatedTransform);
end

if s.doPlot
	figure('name','Estimated transform');
	c_subplot(1,2);
	ptGrps = {s.stationaryPts,s.movingPts};
	grpLabels = {'Stationary','Moving'};
	colors = c_getColors(length(ptGrps));
	markers = '.o';
	for iG = 1:length(ptGrps)
		pts = ptGrps{iG};
		ptArgs = c_mat_sliceToCell(pts,2);
% 		plot3(ptArgs{:},[markers(iG) '-'],'Color',colors(iG,:));
		scatter3(ptArgs{:},[],colors(iG,:),markers(iG));
		hold on;
	end
	legend(grpLabels,'location','SouthOutside');	
	title('Before alignment');
	c_subplot(2,2);
	ptGrps = {s.stationaryPts,movedPts};
	grpLabels = {'Stationary','Moved'};
	colors = c_getColors(length(ptGrps));
	for iG = 1:length(ptGrps)
		pts = ptGrps{iG};
		ptArgs = c_mat_sliceToCell(pts,2);
% 		plot3(ptArgs{:},[markers(iG) '-'],'Color',colors(iG,:));
		scatter3(ptArgs{:},[],colors(iG,:),markers(iG));
		hold on;
	end
	legend(grpLabels,'location','SouthOutside');	
	title('After alignment');
end
end

function testfn()

	origPts = rand(10,3);
% 	origTrans = [
% 		1 0 0 20;
% 		0 1 0.2^2 30;
% 		0 0 1-0.2^2 -10;
% 		0 0 0 1];
	origTrans = [
		1 0 0 1;
		0 0 1 0;
		0 -1 0 0;
		0 0 0 1];
	newPts = c_pts_applyRigidTransformation(origPts,origTrans);
	estTrans = c_pts_estimateAligningTransformation(...
		'movingPts',origPts,...
		'stationaryPts',newPts,....
		'doPlot',false);
	
	origTrans
	estTrans
end

function [R,t] = rigid_transform_3D_SVD(A, B)
% Adapted from http://nghiaho.com/?page_id=671
% This function finds the optimal Rigid/Euclidean transform in 3D space
% It expects as input a Nx3 matrix of 3D points.
% It returns R, t

    if nargin ~= 2
	    error('Missing parameters');
    end

    assert(all(size(A) == size(B)))
	
	% ignore NaNs
	if any(isnan(A(:))) || any(isnan(B(:)))
		indicesToIgnore = all(isnan(A),2) | all(isnan(B),2);
		A = A(~indicesToIgnore,:);
		B = B(~indicesToIgnore,:);
	end

    centroid_A = mean(A);
    centroid_B = mean(B);

    N = size(A,1);

    H = (A - repmat(centroid_A, N, 1))' * (B - repmat(centroid_B, N, 1));

    [U,S,V] = svd(H);

    R = V*U';

    if det(R) < 0
        c_saySingle('Reflection detected');
        V(:,3) = V(:,3)*-1;
        R = V*U';
    end

    t = -R*centroid_A' + centroid_B';
end

