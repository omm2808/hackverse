import 'dart:convert';

/// In-memory tree node interface for high-speed evaluation.
abstract class DecisionTreeNode {
  List<double> evaluate(List<double> features);
}

/// Leaf node carrying class probability vector.
class DecisionTreeLeafNode implements DecisionTreeNode {
  final List<double> probabilities;

  const DecisionTreeLeafNode(this.probabilities);

  @override
  List<double> evaluate(List<double> features) => probabilities;
}

/// Decision split node comparing feature at featureIndex against threshold.
class DecisionTreeSplitNode implements DecisionTreeNode {
  final int featureIndex;
  final double threshold;
  final DecisionTreeNode left;
  final DecisionTreeNode right;

  const DecisionTreeSplitNode({
    required this.featureIndex,
    required this.threshold,
    required this.left,
    required this.right,
  });

  @override
  List<double> evaluate(List<double> features) {
    if (features[featureIndex] <= threshold) {
      return left.evaluate(features);
    } else {
      return right.evaluate(features);
    }
  }
}

/// Prediction result from DecisionForest.
class ForestPrediction {
  final String predictedClass;
  final double confidence;
  final Map<String, double> classProbabilities;

  const ForestPrediction({
    required this.predictedClass,
    required this.confidence,
    required this.classProbabilities,
  });
}

/// High-performance, pure-Dart evaluator for `fit_odyssey_decision_forest_v1` format.
/// Evaluates serialized Random Forest ensembles with sub-millisecond latency.
class DecisionForest {
  final String modelName;
  final String modelVersion;
  final List<String> classes;
  final int numClasses;
  final int numTrees;
  final int numFeatures;
  final List<String> featureNames;
  final List<DecisionTreeNode> trees;

  const DecisionForest({
    required this.modelName,
    required this.modelVersion,
    required this.classes,
    required this.numClasses,
    required this.numTrees,
    required this.numFeatures,
    required this.featureNames,
    required this.trees,
  });

  /// Factory loading and compiling the forest from a JSON Map.
  factory DecisionForest.fromJson(Map<String, dynamic> json) {
    final modelName = json['model_name'] as String? ?? 'UnnamedForest';
    final modelVersion = json['model_version'] as String? ?? '1.0.0';
    final rawClasses = (json['classes'] as List).map((c) => c.toString()).toList();
    final numClasses = json['num_classes'] as int? ?? rawClasses.length;
    final numTrees = json['num_trees'] as int? ?? 0;
    final numFeatures = json['num_features'] as int? ?? 140;
    final featureNames = (json['feature_names'] as List?)
            ?.map((f) => f.toString())
            .toList() ??
        const [];

    final rawTrees = json['trees'] as List;
    final compiledTrees = rawTrees.map((t) => _compileNode(t as Map<String, dynamic>)).toList();

    return DecisionForest(
      modelName: modelName,
      modelVersion: modelVersion,
      classes: rawClasses,
      numClasses: numClasses,
      numTrees: numTrees,
      numFeatures: numFeatures,
      featureNames: featureNames,
      trees: compiledTrees,
    );
  }

  /// Factory loading directly from JSON string.
  factory DecisionForest.fromJsonString(String jsonString) {
    final Map<String, dynamic> jsonMap = json.decode(jsonString) as Map<String, dynamic>;
    return DecisionForest.fromJson(jsonMap);
  }

  static DecisionTreeNode _compileNode(Map<String, dynamic> nodeMap) {
    final type = nodeMap['type'] as String? ?? 'leaf';
    if (type == 'leaf') {
      final rawProbs = (nodeMap['probabilities'] as List)
          .map((p) => (p as num).toDouble())
          .toList();
      return DecisionTreeLeafNode(rawProbs);
    } else {
      final featureIndex = nodeMap['feature_index'] as int;
      final threshold = (nodeMap['threshold'] as num).toDouble();
      final left = _compileNode(nodeMap['left'] as Map<String, dynamic>);
      final right = _compileNode(nodeMap['right'] as Map<String, dynamic>);
      return DecisionTreeSplitNode(
        featureIndex: featureIndex,
        threshold: threshold,
        left: left,
        right: right,
      );
    }
  }

  /// Evaluates the 140-feature vector across all trees and aggregates probabilities.
  ForestPrediction predict(List<double> features) {
    if (features.length < numFeatures) {
      throw ArgumentError(
        'Feature vector length (${features.length}) is less than expected ($numFeatures)',
      );
    }

    final aggregatedProbs = List<double>.filled(numClasses, 0.0);
    final totalTrees = trees.length;

    for (int t = 0; t < totalTrees; t++) {
      final treeProbs = trees[t].evaluate(features);
      for (int c = 0; c < numClasses; c++) {
        aggregatedProbs[c] += treeProbs[c];
      }
    }

    int bestClassIdx = 0;
    double maxProb = -1.0;
    final probMap = <String, double>{};

    for (int c = 0; c < numClasses; c++) {
      final avgP = aggregatedProbs[c] / totalTrees;
      probMap[classes[c]] = avgP;
      if (avgP > maxProb) {
        maxProb = avgP;
        bestClassIdx = c;
      }
    }

    return ForestPrediction(
      predictedClass: classes[bestClassIdx],
      confidence: maxProb,
      classProbabilities: probMap,
    );
  }
}
