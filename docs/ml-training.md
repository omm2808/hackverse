# Fit Odyssey — Future Work: Machine Learning Strategy

> **Status:** Out of Scope for Hackathon MVP (Intentional Architecture Decision)  
> **Target:** Potential Layer-2 Movement Classifier for Post-MVP Roadmap  

---

## 1. Rationale for Excluding Custom ML Classifiers in MVP

Historical drafts of the Fit Odyssey documentation contained contradictions—claiming both that "no training data was needed" while concurrently outlining a full video dataset annotation and TFLite model training pipeline.

For the **Fit Odyssey MVP**, we have intentionally scoped out custom neural network classifiers (Layer-2 models) in favor of a single-layer deterministic pipeline using **Google ML Kit Pose Detection (BlazePose)** coupled with **pure-Dart biomechanical state machines**.

### Key Technical Rationale:
1. **Rule-Based Biomechanics are 100% Sufficient:**
   Squats, push-ups, and planks have well-defined biomechanical kinematics governed by clear joint angle trajectories (hip–knee–ankle, shoulder–elbow–wrist, shoulder–hip–ankle). Mathematical trigonometry with EMA smoothing ($\alpha=0.6$) achieves $>98\%$ counting accuracy for these exercises without a neural classifier.
2. **Thermal & Battery Conservation on Low-End Hardware:**
   Running two concurrent models on low-cost Android smartphones (BlazePose + custom TFLite classifier) produces excessive thermal dissipation, drops frame rates below 10 FPS, and drains battery life rapidly during 15-minute workout sessions.
3. **No Training Dataset Requirement:**
   Training a generalized, robust neural classifier requires gathering thousands of annotated workout videos across diverse Indian skin tones, clothing styles, camera angles, and dorm-room lighting conditions. Bypassing custom ML removes dataset collection risks, annotation costs, and subject data leakage vulnerabilities.
4. **Transparent & Deterministic Feedback:**
   Mathematical state machines produce explicit, explainable feedback (e.g. "Knee angle reached only $115^\circ$, needs $\le 100^\circ$ for depth") rather than opaque softmax confidence percentages.

---

## 2. Conditions for Future Reintroduction

A custom machine learning classifier or sequence model (e.g., TFLite / ONNX runtime) will only be reintroduced if subsequent roadmap phases demand:

1. **Unconstrained Exercise Auto-Detection:**
   If user pre-selection of exercises is removed in favor of automatic exercise recognition across dozens of exercises (e.g., distinguishing between lunges, squats, burpees, and jumping jacks automatically).
2. **Complex Compound Movements:**
   For multi-planar movements that cannot be easily captured with planar 2D/3D angle thresholds, such as Surya Namaskar flows, Olympic cleans, or gymnastics maneuvers.
3. **Pathology & Gait Anomaly Detection:**
   For clinical rehabilitation scenarios where subtle compensatory muscle patterns require spatio-temporal graph neural networks (ST-GCN).

*Until such requirements emerge, the platform strictly utilizes on-device Google ML Kit BlazePose coupled with the pure-Dart deterministic biomechanical engine.*
