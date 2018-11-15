%% Tests whether each item passed in items is of type className
function result = iseach(items, className)
    result = true;
    for i=1:numel(items)
        if ~isa(items(i), className)
            result = false;
            return
        end
    end
end