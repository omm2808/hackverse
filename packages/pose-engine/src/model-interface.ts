/**
 * Model interfaces and metadata contracts for Layer 2 Custom AI Models.
 */

export interface ModelMetadata {
  modelName: string;
  modelVersion: string;
  datasetVersion: string;
  trainingDate: string;
  classes: string[];
  inputShape: number[];
  outputClasses: string[];
  featureConfiguration: Record<string, string | number | boolean>;
  modelFormat: 'tflite' | 'onnx' | 'tfjs' | 'json';
}

export interface ModelPrediction {
  predictedClass: string;
  confidence: number;
  probabilities: Record<string, number>;
  movementState?: string;
}

export interface CustomModelPredictor {
  readonly metadata: ModelMetadata;
  predict(features: number[]): Promise<ModelPrediction> | ModelPrediction;
}
