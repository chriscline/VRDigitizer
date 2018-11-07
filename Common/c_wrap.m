function out = c_wrap(f, out_indices)

% adapted from http://www.mathworks.com/matlabcentral/fileexchange/39735-functional-programming-constructs

[outs{1:max(out_indices)}] = f();
out = outs(out_indices);
    
end