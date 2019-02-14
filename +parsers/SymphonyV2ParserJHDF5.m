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
classdef SymphonyV2ParserJHDF5 < parsers.SymphonyParserJHDF5

    % experiement (1)
    %   |__devices (1)
    %   |__epochGroups (2)
    %   |   |_epochGroup-uuid
    %   |       |_epochBlocks (1)
    %   |           |_<protocol_class>-uuid (1) #protocols
    %   |               |_epochs (1)
    %   |               |   |_epoch-uuid (1)    #h5EpochLinks
    %   |               |      |_background (1)
    %   |               |      |_protocolParameters (2)
    %   |                |      |_responses (3)
    %   |                |        |_<device>-uuid (1)
    %   |                |            |_data (1)
    %   |                |_protocolParameters(2)
    %   |__properties
    %   |__resources
    %   |__sources
    
    methods

        function obj = SymphonyV2ParserJHDF5(fname)
            obj = obj@parsers.SymphonyParserJHDF5(fname);
        end

        function obj = parse(obj)
            import ch.systemsx.cisd.hdf5.*;
            obj.reader = HDF5Factory.openForReading(obj.fname);
            rootMembers = obj.reader.getGroupMemberInformation('/',true);

            m = rootMembers.get(5); % Get the experiment root
            expMembers = obj.reader.getGroupMemberInformation(m.getPath(), true); % Go to the next level down

            for k = 0 : expMembers.size()-1
                str = obj.parseH5Name(char(expMembers.get(k).getPath()));
                
                switch str
                    case 'devices'
                    case 'epochGroups'
                        obj.groupInfo = containers.Map(); % Initialize your group information HashMap.
                        gInfo = obj.reader.getGroupMemberInformation(expMembers.get(k).getPath(), true); % Get the group info.
                        for m = 0 : gInfo.size()-1
                            atts = obj.mapAttributes(gInfo.get(m).getPath());     % Get the epochGroup attributes.
                            obj.groupInfo(atts('uuid')) = gInfo.get(m).getPath(); % Copy the path to the hash.
                        end                        
                    case 'properties'
                         props = obj.mapAttributes(expMembers.get(k).getPath());
                    case 'resources'
                    case 'sources'
                        % Get the source hierarcy.
                        sourceInfo = expMembers.get(k).getPath();   
                        obj.getSourceHierarchy(sourceInfo);                        
                end
            end
            
            obj.reader.close();

        end
        
        function getSourceHierarchy(obj, sourceInfo)
            import ch.systemsx.cisd.hdf5.*

            % Get the experiment path.
            expPath = obj.reader.getGroupMemberInformation(sourceInfo, true).get(0).getPath();
            
            % Populate the Experiment source.
            %obj.getExperimentSource(expPath);
            
            % Loop through and get all of the Preparations
            pInfo = obj.reader.getGroupMemberInformation([char(expPath), '/sources'],true);
            for k = 0 : pInfo.size()-1
                pSrc = pInfo.get(k).getPath();
                
                % Create a Preparation and add properties, etc.
                %preparation = Preparation();
                %preparation = obj.getSource(pSrc, preparation);
                
                % Check for Cells.
                cellInfo = obj.reader.getGroupMemberInformation([char(pSrc), '/sources'], true);
                % Loop through the cells.
                for m = 0 : cellInfo.size()-1
                    cellSrc = cellInfo.get(m).getPath();
                    
                    cell = CellData(); %TODO: populate properly this structure with data            
                    cell.attributes = containers.Map();
                    cell.attributes('parsedDate') = datestr(datetime('today'));
                    cell.attributes('symphonyVersion') = obj.getVersion(obj.fname);
                    cell.attributes('h5File') = obj.fname;
                    
                    % Populate with properties.
                    cell = obj.getSource(cellSrc, cell);
                    
                    disp(['Processing cell ', cell.attributes('label'), ' ...']);
                    
                    if cellSrc.size() > 0
                        egInfo = obj.reader.getGroupMemberInformation([char(cellSrc), '/epochGroups'], true);
                        
                        % Parse the Epoch Groups.
                        % cell.attributes('Nepochs') = numel(h5Epochs); %TODO: calculate amount of epochs
                        
                        for n = 0 : egInfo.size()-1
                            egSrc = egInfo.get(n).getPath();
                            [epochGroup, hasEpochs] = obj.parseEpochGroup(egSrc);
                            
                            % Add the EpochGroup to the Cell.
                            if hasEpochs
                                c.AddEpochGroup(epochGroup);
                                %cell.epochs = epochData; %TODO use this
                            end
                        end
                        
                        % Add the Cell to the Preparation.
                        disp(['Adding cell ' cell.attributes('label') ' ...']);
                        %preparation.AddCell(c);
                        obj.cellDataList{end + 1} = cellData;
                        
                    end
                end
                
                % Add the Preparation to the Experiment.
                %disp(['Adding preparation ', char(preparation.label),' ...']);
                %obj.experiment.AddPreparation(preparation);                
            end
        end

        function [epochGroup, hasEpochs] = parseEpochGroup(obj, eg)
            import ch.systemsx.cisd.hdf5.*;
            
            hasEpochs       = false;                                    % Boolean: Add the EpochGroup? Don't add unless it has epochs.
            groupAttributes = obj.mapAttributes(eg);                    % Get the EpochGroup Attributes.
            eg              = obj.groupInfo(groupAttributes('uuid'));   % Search for the EpochGroup in the epochGroup tree.
            epochGroup      = Group(eg);                                % Create a new EpochGroup.
            
            % Add attributes to the EpochGroup.
            if groupAttributes.isKey('uuid')
                epochGroup.attributes('uuid') = groupAttributes('uuid');
            end
            if groupAttributes.isKey('label')
                epochGroup.attributes('label') = groupAttributes('label');
            end
            if groupAttributes.isKey('startTimeDotNetDateTimeOffsetTicks')
                %epochGroup.SetStartTime( ...
                %    groupAttributes.startTimeDotNetDateTimeOffsetTicks, ...
                %    groupAttributes.startTimeDotNetDateTimeOffsetOffsetHours);
            end
            if groupAttributes.isKey('endTimeDotNetDateTimeOffsetTicks')
                %epochGroup.SetEndTime(...
                %    groupAttributes.endTimeDotNetDateTimeOffsetTicks, ...
                %    groupAttributes.endTimeDotNetDateTimeOffsetOffsetHours);
            end

            % Parse the group.
            eGroup = obj.reader.getGroupMemberInformation(eg, true);
            for m = 0 : eGroup.size()-1
                str = obj.parseH5Name(char(eGroup.get(m).getPath()));
                
                switch str
                    case 'epochBlocks'
                        [epochGroup, hasEpochs] = obj.parseBlocks(epochGroup, eGroup.get(m).getPath());
                    case 'epochGroups' 
                    case 'experiment'
                    case 'properties'
                        props = getAttributes(eGroup.get(m).getPath(), fname, reader); % Get properties

                        % Add properties.
                        fnames = fieldnames(props);
                        for k = 1 : length(fnames)
                            epochGroup.AddProperty(fnames{k}, props.(fnames{k}));
                        end
                    case 'resources'
                    case 'source'
%                         sInfo = reader.getGroupMemberInformation(eGroup.get(m).getPath(), true);
                end
            end
        end
        
        function [epochGroup, hasEpochs] = parseBlocks(obj, epochGroup, blocks)
            import ch.systemsx.cisd.hdf5.*;
            hasEpochs = false;
            
            % Pull the information from the blocks.
            blockInfo = obj.reader.getGroupMemberInformation(blocks, true);
            if blockInfo.size() > 0
                % Loop through and parse each Epoch block.
                for n = 0 : blockInfo.size()-1
                    block = obj.reader.getGroupMemberInformation(blockInfo.get(n).getPath(), true);
                    
                    % Get the block parameters.
                    blockParams = obj.mapAttributes(blockInfo.get(n).getPath());

                    if block.size() > 0                      
                        epochInBlock = false;
                        
                        for o = 0 : block.size()-1
                            tmp = obj.parseH5Name(char(block.get(o).getPath()));
                            if strcmp(tmp, 'epochs')
                                % Pull the epochs info
                                epochs = obj.reader.getGroupMemberInformation(block.get(o).getPath(), true);
                                if epochs.size() > 0
                                    hasEpochs = true;
                                    epochInBlock = true;
                                end
                            elseif strcmp(tmp, 'protocolParameters')
                                commonParameters = obj.mapAttributes(block.get(o).getPath());
                                
                                % Look for the protocolID.
                                if blockParams.isKey('protocolID')
                                    commonParameters('protocolID') = blockParams('protocolID');
                                end
                            end
                        end
                        
                        % Parse each Epoch.
                        if epochInBlock
                            disp(['Parsing epochs in block: ', obj.parseH5Name(char(blockInfo.get(n).getPath()))]);
                            epochGroup = obj.parseEpochs(epochGroup, epochs, commonParameters);
                        end
                    end
                end
            end
        end

        function epochGroup = parseEpochs(obj, epochGroup, epochs, commonParameters)
            import ch.systemsx.cisd.hdf5.*;

            % Now that you have the common parameters, parse the epochs.
            for c = 0 : epochs.size()-1                
                epoch = EpochData(); % Create an Epoch object.
                
                disp(['Parsing ', obj.parseH5Name(char(epochs.get(c).getPath()))]);

                % Get the epoch attributes.
                eAtt = obj.mapAttributes(epochs.get(c).getPath());
                
                % Look for a protocolID.
                if commonParameters.isKey('protocolID')
                    epoch.attributes('protocolID') = commonParameters('protocolID');
                elseif eAtt.isKey('protocolID')
                    epoch.attributes('protocolID') = eAtt('protocolID');
                end

                epoch.attributes = eAtt; % Add attributes to the Epoch.
                %epoch.parentExperimentID = obj.experiment.id;  % Experiment id.

                % backgrounds, epochBlock, protocolParameters, responses, stimuli
                egr = obj.reader.getGroupMemberInformation(epochs.get(c).getPath(), true);
                for d = 0 : egr.size()-1
                    name = obj.parseH5Name(char(egr.get(d).getPath()));
                    
                    if strcmp(name, 'protocolParameters')
                        protocolParams = obj.mapAttributes(egr.get(d).getPath());

                        % Combine protocol parameters.
                        % Concatenate the two maps:
                        protocolParams = [commonParameters; protocolParams];

                        % Add the protocol parameters to the epoch.
                        epoch.attributes = [epoch.attributes;  protocolParams];
                    elseif strcmp(name, 'responses') % Pull responses
                        responses = obj.reader.getGroupMemberInformation(egr.get(d).getPath(), true);
                        if responses.size() > 0
                            for e = 0 : responses.size()-1
                                [response, deviceName] = obj.getResponse(responses.get(e).getPath());
                                % Add the Response to the Epoch.
                                %epoch.AddResponse(deviceName, response);
                                epoch.addDerivedResponse('main_response', response, deviceName); %TODO: fix this with adding the main response to EpochData class
                            end
                        end
                    elseif strcmp(name, 'stimuli')
                        stimuli = reader.getGroupMemberInformation(egr.get(d).getPath(), true);
                        stimulus = obj.getStimulus(stimuli, fname, reader);
                        % Add the Stimulus to the Epoch.
                        epoch.stimulus = stimulus;
                    end
                end

                epochGroup.AddEpoch(epoch.id); % Add the Epoch to the EpochGroup.
            end
        end
        
        function [response, deviceName] = getResponse(obj, src)
            import ch.systemsx.cisd.hdf5.*;
            
            % Loop through the groups.
            devs = obj.reader.getGroupMemberInformation(src, true);
            for k = 0 : devs.size()-1
                name = obj.parseH5Name(char(devs.get(k).getPath()));
                switch name
                    case 'device'
                        % Get the attributes.
                        atts = obj.mapAttributes(devs.get(k).getPath());
                        deviceName = atts('name');                        
                end
            end            
            
            % Get the device data.
            objInfo = obj.reader.getObjectInformation([char(src),'/data']);
            if objInfo.exists()
                dset = h5read(obj.fname, [char(src),'/data']);
                % Get the quantity and units of the response.
                response.data = dset.quantity;
                % Get the units.
                response.units = deblank(dset.units(:,1)');
            end
        end                
        
        function srcObj = getSource(obj, src, srcObj)
            % Populates the passed object obj with properties
            import ch.systemsx.cisd.hdf5.*
            
            % Experiment attributes.
            atts = obj.mapAttributes(src);
            % Add the attributes to the experiment.
            if atts.isKey('uuid')
                srcObj.attributes('uuid') = atts('uuid');
            end         
            if atts.isKey('label')
                srcObj.attributes('label') = atts('label');
                disp(['Reading source: ', atts('label'),' ...']);
            end
            if atts.isKey('keywords')
                srcObj.attributes('keywords') = atts('keywords');

                %splits = strsplit(atts('keywords'), ',');
                %for k = 1 : length(splits)
                %    srcObj.attribute(splits{k});
                %end
            end
            if atts.isKey('creationTimeDotNetDateTimeOffsetTicks')
                %srcObj.SetCreationTime(...
                %    atts.creationTimeDotNetDateTimeOffsetTicks, ...
                %    atts.creationTimeDotNetDateTimeOffsetOffsetHours);
            end
            
            % Get notes.
            objInfo = obj.reader.getObjectInformation([char(src),'/notes']);
            if objInfo.exists()
                dset = h5read(obj.fname, [char(src),'/notes']);
                for m = 1 : length(dset.text)
                    %srcObj.AddNote(dset.time.ticks(m),...
                    %    dset.time.offsetHours(m), dset.text{m});
                end
            end
                        
            props = obj.mapAttributes([char(src), '/properties']); % Get properties.
            % Add properties.
            for k = props.keys
                srcObj.attributes(k{:}) = props(k{:});
            end
        end        
        
        function getExperimentSource(obj, src)
            import ch.systemsx.cisd.hdf5.*
            
            % Experiment attributes.
            atts = mapAttributes(src, obj.fname, obj.reader);
            % Add the attributes to the experiment.
            if atts.isKey('uuid')
                obj.experiment.id = atts('uuid');
            end  
            if atts.isKey('label')
                obj.experiment.label = atts('label');
                disp(['Reading Experiment: ',atts('label'),' ...']);
            end
            if atts.isKey('keywords')
                splits = strsplit(atts('keywords'), ',');
                for k = 1 : length(splits)
                    obj.experiment.AddKeyword(splits{k});
                end
            end
            if atts.isKey('creationTimeDotNetDateTimeOffsetTicks')
%                 obj.experiment.SetCreationTime(...
%                     atts('creationTimeDotNetDateTimeOffsetTicks'), ...
%                     atts('creationTimeDotNetDateTimeOffsetOffsetHours'));
            end
            
            % Get notes.
            objInfo = reader.getObjectInformation([char(src),'/notes']);
            if objInfo.exists()
                dset = h5read(fname, [char(src),'/notes']);
                for m = 1 : length(dset.text)
%                     obj.experiment.AddNote(dset.time.ticks(m),...
%                         dset.time.offsetHours(m), dset.text{m});
                end
            end
            
            % Get properties.
            props = mapAttributes([char(src), '/properties']);
            
            % Add properties.
            keys = props.keys;
            for k = props.keys
%                 obj.experiment.AddProperty(k, props(k));
            end
            
        end
        
        function cell = buildCellData(obj, label, h5Epochs)
            cell = CellData();

            epochsTime = arrayfun(@(epoch) h5readatt(obj.fname, epoch.Name, 'startTimeDotNetDateTimeOffsetTicks'), h5Epochs);
            [time, indices] = sort(epochsTime);
            sortedEpochTime = double(time - time(1)).* 1e-7;

            lastProtocolId = [];
            epochData = EpochData.empty(numel(h5Epochs), 0);
            disp(['Building cell data for label [' label ']']);
            disp(['Total number of epochs [' num2str(numel(h5Epochs)) ']']);

            for i = 1 : numel(h5Epochs)
                disp(['Processing epoch #' num2str(i)]);
                index = indices(i);
                epochPath = h5Epochs(index).Name;
                [protocolId, name, protocolPath] = obj.getProtocolId(epochPath);

                if ~ strcmp(protocolId, lastProtocolId)
                    % start of new protocol
                    parameterMap = obj.buildAttributes(protocolPath);
                    name = strsplit(name, '.');
                    name = obj.convertDisplayName(name{end});
                    parameterMap('displayName') = name;

                    % add epoch group properties to current prtoocol
                    % parameters
                    group = h5Epochs(index).Name;
                    endOffSet = strfind(group, '/epochBlocks');
                    epochGroupLabel = h5readatt(obj.fname, group(1 : endOffSet), 'label');
                    parameterMap('epochGroupLabel') = epochGroupLabel;
                    parameterMap = obj.buildAttributes([group(1 : endOffSet) 'properties'], parameterMap);

                end
                lastProtocolId = protocolId;
                parameterMap = obj.buildAttributes(h5Epochs(index).Groups(end-2), parameterMap);  % DIRTY FIX AFTER BATHTEMP ADDITION
                parameterMap('epochNum') = i;
                parameterMap('epochStartTime') = sortedEpochTime(i);
                parameterMap('epochTime') = dotnetTicksToDateTime(epochsTime(index));

                e = EpochData();
                e.parentCell = cell;
                e.attributes = containers.Map(parameterMap.keys, parameterMap.values);

                e.dataLinks = obj.getResponses(h5Epochs(index).Groups(end-1).Groups); % DIRTY FIX AFTER BATHTEMP ADDITION
                e.responseHandle = @(e, path) h5read(e.parentCell.get('h5File'), path);
                epochData(i) = e;
            end

            cell.attributes = containers.Map();
            cell.epochs = epochData;
            cell.attributes('Nepochs') = numel(h5Epochs);
            cell.attributes('parsedDate') = datestr(datetime('today'));
            cell.attributes('symphonyVersion') = 2.0; % WHY IS THIS HARDCODED?
            cell.attributes('h5File') = obj.fname;
            %cell.attributes('recordingLabel') =  ['c' char(regexp(label,'[0-9]+', 'match'))]; % LDS: this requires cells to be called "c1...cn"
        end

        function epochGroupMap = getEpochsByCellLabel(obj, epochGroups)
            epochGroupMap = containers.Map();

            for i = 1 : numel(epochGroups)
                h5Epochs = flattenByProtocol(epochGroups(i).Groups(1).Groups);
                label = obj.getSourceLabel(epochGroups(i));
                epochGroupMap = addToMap(epochGroupMap, label, h5Epochs');
            end

            function epochs = flattenByProtocol(protocols)
                epochs = arrayfun(@(p) p.Groups(1).Groups, protocols, 'UniformOutput', false);
                idx = find(~ cellfun(@isempty, epochs));
                epochs = cell2mat(epochs(idx));
            end
        end

        function label = getSourceLabel(obj, epochGroup)

            % check if it is h5 Groups
            % if not present it should be in links
            if numel(epochGroup.Groups) >= 4
                source = epochGroup.Groups(end).Name;
            else
                source = epochGroup.Links(2).Value{:};
            end
            try
                label = h5readatt(obj.fname, source, 'label');
            catch
                source = epochGroup.Links(2).Value{:};
                label = h5readatt(obj.fname, source, 'label');
            end
        end

        function attributeMap = buildAttributes(obj, h5group, map)
            if nargin < 3
                map = containers.Map();
            end
            attributeMap = obj.mapAttributes(h5group, map);
        end

        function sourceTree = buildSourceTree(obj, sourceLink, sourceTree, level)
            % The most time consuming part while parsing the h5 file

            if nargin < 3
                sourceTree = tree();
                level = 0;
            end
            sourceGroup = h5info(obj.fname, sourceLink);

            label = h5readatt(obj.fname, sourceGroup.Name, 'label');
            map = containers.Map();
            map('label') = label;

            sourceProperties = [sourceGroup.Name '/properties'];
            map = obj.mapAttributes(sourceProperties, map);

            sourceTree = sourceTree.addnode(level, map);
            level = level + 1;
            childSource = h5info(obj.fname, [sourceGroup.Name '/sources']);

            for i = 1 : numel(childSource.Groups)
                sourceTree = obj.buildSourceTree(childSource.Groups(i).Name, sourceTree, level);
            end
        end

        function [id, name, path] = getProtocolId(~, epochPath)

            indices = strfind(epochPath, '/');
            id = epochPath(indices(end-2) + 1 : indices(end-1) - 1);
            path = [epochPath(1 : indices(end-1) - 1) '/protocolParameters'] ;
            nameArray = strsplit(id, '-');
            name = nameArray{1};
        end

        function map = getResponses(~, responseGroups)
            map = containers.Map();

            for i = 1 : numel(responseGroups)
                devicePath = responseGroups(i).Name;
                indices = strfind(devicePath, '/');
                id = devicePath(indices(end) + 1 : end);
                deviceArray = strsplit(id, '-');

                name = deviceArray{1};
                path = [devicePath, '/data'];
                map(name) = path;
            end
        end

        function map = getSourceAttributes(~, sourceTree, label, map)
            id = find(sourceTree.treefun(@(node) ~isempty(node) && strcmp(node('label'), label)));

            while id > 0
                currentMap = sourceTree.get(id);
                id = sourceTree.getparent(id);

                if isempty(currentMap)
                    continue;
                end

                keys = currentMap.keys;
                for i = 1 : numel(keys)
                    k = keys{i};
                    map = addToMap(map, k, currentMap(k));
                end
            end
        end

    end
end

