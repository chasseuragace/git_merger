

# Merge Pipeline Automation

This repository contains a step-wise merge pipeline that automates the process of validating, merging, retrying failed merges, and analyzing conflicts. 

## 📌 Overview

The pipeline consists of several shell scripts and a Dart script that categorize and analyze branch conflicts based on **Clean Architecture with Riverpod**. It ensures smooth merging by following a structured order.

## 🔧 Pipeline Workflow

The execution flow follows these steps:

1️⃣ **Validate Merges** → `validate_merges.sh`  
2️⃣ **Merge Branches** → `branch-merger.sh`  
3️⃣ **Retry Failed Merges** → `retry-failed-merges.sh`  
4️⃣ **Analyze Conflicts** → `primary_analysis.sh`  
5️⃣ **Perform Dart Code Analysis** → `dart analyze.dart`  

All logs are saved in **`merge_pipeline.log`** for debugging.

---

## 🚀 How to Run the Pipeline

### **1️⃣ Setup & Make Executable**
Before running, ensure all scripts have execution permissions:

```sh
chmod +x run_merge_pipeline.sh
chmod +x validate_merges.sh
chmod +x branch-merger.sh
chmod +x retry-failed-merges.sh
chmod +x primary_analysis.sh
```

---

### **2️⃣ Execute the Pipeline**
Run the pipeline script:

```sh
./run_merge_pipeline.sh
```

---

### **3️⃣ Monitor Logs**
Check **merge logs** in real-time:

```sh
tail -f merge_pipeline.log
```

Or view the full log file:

```sh
cat merge_pipeline.log
```

---

## 📂 File Structure

```
📂 project-root
 ├── 📄 run_merge_pipeline.sh    # Main script to run all steps
 ├── 📄 validate_merges.sh       # Step 1: Validates pending merges
 ├── 📄 branch-merger.sh         # Step 2: Merges branches in order
 ├── 📄 retry-failed-merges.sh   # Step 3: Retries failed merges
 ├── 📄 primary_analysis.sh      # Step 4: Analyzes conflict files
 ├── 📄 analyze.dart             # Step 5: Performs Dart analysis
 ├── 📄 merge_pipeline.log       # Log file for debugging
 ├── 📂 output/
 │   ├── retry_results.json      # JSON with merge retry details
 │   ├── merge_order.json        # Suggested merge order output
 │   ├── conflict_details.json   # Debug info on conflicts
 └── 📄 README.md                # Documentation (this file)
```

---

## 📊 Expected Output Files

- **`merge_order.json`** → Stores the suggested branch merge sequence.
- **`conflict_details.json`** → Contains per-branch conflict data.
- **`merge_pipeline.log`** → Logs all script executions for debugging.

---

## 🛠️ Troubleshooting

❌ **"Permission Denied" error?**  
✅ Run:  
```sh
chmod +x *.sh
```

❌ **Pipeline stops on an error?**  
✅ Check **`merge_pipeline.log`** for details and fix the issue.

❌ **Merges causing conflicts?**  
✅ Inspect **`conflict_details.json`** to understand which files are conflicting.

---

## 📢 Contributing

Feel free to modify the scripts and improve the merge automation process. If you find issues or need improvements, open a pull request! 🚀

---

## 📄 License

This project is open-source and available under the **MIT License**.

