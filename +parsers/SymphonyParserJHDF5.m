%% Clarinet: Electrophysiology time series data analysis
% Copyright (C) 2018 Luca Della Santina
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
classdef SymphonyParserJHDF5 < handle

    properties
        fname
        info
        cellDataList
        
        reader    % HDF5 java reaser object    
        groupInfo % Map of all the uuids of the epochGroups     
        sources  
        experiment
        devices
    end

    methods

        function obj = SymphonyParserJHDF5(fname)
            % Find local absolute path of parsers, load jar from there
            p = what('parsers');
            javaaddpath([p.path filesep 'cisd-jhdf5.jar']);            
            import ch.systemsx.cisd.hdf5.*;
            
            obj.cellDataList = {};
            obj.fname = fname;
        end

        function map = mapAttributes(obj, h5group, map)
            if nargin < 3
                map = containers.Map();
            end
            
            attributes = obj.reader.getAttributeNames(h5group);                
            if attributes.size() > 0
                for i = 0 : attributes.size()-1
                    name = char(attributes.get(i));
                    value = h5readatt(obj.fname, char(h5group), name);

                    if strcmpi(name, 'symphony.uuid')
                        name = 'uuid';
                    end

                    % convert column vectors to row vectors
                    if size(value, 1) > 1
                        value = reshape(value, 1, []);
                    end

                    map(name) = value;
                end
            end
        end
        
        function hrn = convertDisplayName(~, n)
            hrn = regexprep(n, '([A-Z][a-z]+)', ' $1');
            hrn = regexprep(hrn, '([A-Z][A-Z]+)', ' $1');
            hrn = regexprep(hrn, '([^A-Za-z ]+)', ' $1');
            hrn = strtrim(hrn);

            % TODO: improve underscore handling, this really only works with lowercase underscored variables
            hrn = strrep(hrn, '_', '');

            hrn(1) = upper(hrn(1));
        end

        function r = getResult(obj)
            r = obj.cellDataList;
        end
        
        function atts = getAttributes(obj, h5group)
            atts = struct();
            attributes = obj.reader.getAttributeNames(h5group);
            if attributes.size() > 0
                for i = 0 : attributes.size()-1
                    name = char(attributes.get(i));
                    
                    if strcmpi(name, 'symphony.uuid')
                        atts.uuid = h5readatt(obj.fname, char(h5group), name);
                    else
                        atts.(name) = h5readatt(obj.fname, char(h5group), name);
                    end
                end
            end
        end
        
        function names = getKeyNames(obj, keys)
            
            names = cell(1,keys.Count);
            
            keys_enum = keys.GetEnumerator;
            stat = 1;
            count = 0;
            while stat
                stat = keys_enum.MoveNext();
                if stat
                    count = count + 1;
                    key = keys_enum.Current;
                    
                    names{count} = char(key);
                end
            end
        end
        
        function n = parseH5Name(obj, name)            
            splits = strsplit(name, '/');
            n = splits{end};
        end
    end

    methods(Abstract)
        parse(obj)
    end

    methods(Static)
        function version = getVersion(fname)
            import ch.systemsx.cisd.hdf5.*;
            reader = HDF5Factory.openForReading(fname);
            version = reader.getIntAttribute('/','version');
        end
    end
end

