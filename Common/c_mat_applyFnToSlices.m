function res = c_mat_applyFnToSlices(fn,mat,sliceInputDims,sliceOutputDims)
if nargin==0, testfn(); return; end;

sliceDims = sliceInputDims;
assert(~islogical(sliceDims)); % could add code to handle this
nonsliceDims = 1:ndims(mat);
nonsliceDims(sliceDims) = [];

matSz = size(mat);
mat = permute(mat,[sliceDims, nonsliceDims]);
mat = reshape(mat,[matSz(sliceDims), prod(matSz(nonsliceDims))]);
mat = permute(mat,[length(sliceDims)+1, 1:length(sliceDims)]);

assert(length(sliceDims)<5); % could modify below to support more dimensions

for i=1:size(mat,1)
	tmp = fn(permute(mat(i,:,:,:,:),[2:ndims(mat) 1]));
	if i==1
		sliceOutputSize = size(tmp);
		if nargin > 3
			assert(length(sliceOutputSize) <= length(sliceOutputDims));
		else
			% set sliceOutputDims automatically
			if isequal(sliceOutputSize,matSz(sliceDims))
				sliceOutputDims = sliceInputDims; % output size matches input size
			else
				keyboard %TODO
			end
		end
		assert(length(sliceOutputSize)<5)
		res = nan([size(mat,1), sliceOutputSize]);
	end
	res(i,:,:,:,:) = tmp;
end

res = permute(res,[1+(1:length(sliceOutputSize)),1]); % move slice dimension to last
res = reshape(res,[sliceOutputSize, matSz(nonsliceDims)]);
if length(sliceOutputSize) <= length(matSz(sliceDims))
	res = ipermute(res,[sliceDims(1:length(sliceOutputSize)), nonsliceDims]);
else
	keyboard %TODO
end
end



function testfn()

a = rand(3,3,10);
b = rand(3,3);
prods = c_mat_applyFnToSlices(@(x) x*b,a,1:2);
altProds = nan(size(a));
for i=1:size(a,3)
	altProds(:,:,i) = a(:,:,i)*b;
end
assert(isequal(prods,altProds));

a = rand(10,3,3);
b = rand(3,3);
prods = c_mat_applyFnToSlices(@(x) x*b,a,2:3);
altProds = nan(size(a));
for i=1:size(a,1)
	altProds(i,:,:) = squeeze(a(i,:,:))*b;
end
assert(isequal(prods,altProds));


a = rand(3,4,5);
means = c_mat_applyFnToSlices(@(x) mean(x,1),a,1:2);
altMeans = mean(a,1);
assert(isequal(means,altMeans))

keyboard

end