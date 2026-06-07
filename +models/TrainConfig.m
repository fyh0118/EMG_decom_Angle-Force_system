classdef TrainConfig
    % TrainConfig - CNN-biLSTM模型训练参数配置

    properties
        WindowMs        double = 200
        StepMs          double = 100
        Fs              double = 2000
        FeatureType     string = 'CumulativeSpikeCount'
        BatchSize       double = 32
        MaxEpochs       double = 100
        LearningRate    double = 0.001
        ValidationSplit double = 0.2
        UseRMSBaseline  logical = false
        OutputType      string = 'dual'   % 'angle_only' | 'force_only' | 'dual'
    end

    methods
        function obj = TrainConfig()
        end

        function windowSamples = getWindowSamples(obj)
            windowSamples = round(obj.WindowMs / 1000 * obj.Fs);
        end

        function stepSamples = getStepSamples(obj)
            stepSamples = round(obj.StepMs / 1000 * obj.Fs);
        end
    end
end
