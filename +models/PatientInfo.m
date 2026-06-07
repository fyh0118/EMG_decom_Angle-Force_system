classdef PatientInfo
    % PatientInfo - 患者信息数据类

    properties
        PatientID    string = ""
        Name         string = ""
        Gender       string = ""
        Age          double = NaN
        AffectedSide string = ""       % 患侧: 'Left', 'Right'
        Diagnosis    string = ""       % 诊断信息
        Notes        string = ""       % 备注
        CreatedDate  datetime
        UpdatedDate  datetime
    end

    methods
        function obj = PatientInfo()
            obj.CreatedDate = datetime('now');
            obj.UpdatedDate = datetime('now');
        end

        function label = getDisplayLabel(obj)
            if obj.Name ~= "" && obj.PatientID ~= ""
                label = sprintf('%s (%s)', obj.Name, obj.PatientID);
            elseif obj.PatientID ~= ""
                label = obj.PatientID;
            else
                label = '未命名患者';
            end
        end

        function s = toStruct(obj)
            s.PatientID = obj.PatientID;
            s.Name = obj.Name;
            s.Gender = obj.Gender;
            s.Age = obj.Age;
            s.AffectedSide = obj.AffectedSide;
            s.Diagnosis = obj.Diagnosis;
            s.Notes = obj.Notes;
            s.CreatedDate = obj.CreatedDate;
            s.UpdatedDate = obj.UpdatedDate;
        end

        function obj = fromStruct(obj, s)
            obj.PatientID = s.PatientID;
            obj.Name = s.Name;
            obj.Gender = s.Gender;
            obj.Age = s.Age;
            obj.AffectedSide = s.AffectedSide;
            obj.Diagnosis = s.Diagnosis;
            obj.Notes = s.Notes;
            obj.CreatedDate = s.CreatedDate;
            obj.UpdatedDate = s.UpdatedDate;
        end
    end
end
