%% Clarinet: Electrophysiology time series analysis
% Copyright (C) 2018-2020 Luca Della Santina
%
%  This file is part of Clarinet
%
% This program is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.
% This software is released under the terms of the GPL v3 software license
%
%% Tests whether each item passed in items is of type className
function result = iseach(items, className)
result = true;
if iscell(items)
    for i=1:numel(items)
        if ~isa(items{i}, className)
            result = false;
            return
        end
    end
else
    for i=1:numel(items)
        if ~isa(items(i), className)
            result = false;
            return
        end
    end
end
end