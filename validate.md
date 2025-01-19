
# 🔄 Merge Validation Script

This **Bash script** automates the process of validating and analyzing merges between branches in a Git repository. It checks if branches can be cleanly merged into a target branch, detects conflicts, and logs the results in a structured **JSON file**.

---

## 📌 Overview

This script:
✔️ Identifies branches that are **not merged** into `develop`.  
✔️ Checks if the last commit on each branch is **after** a given date.  
✔️ Attempts a **dry-run merge** to detect conflicts.  
✔️ Logs **success/failure** status along with conflict details.  
✔️ Outputs a **JSON report** summarizing the merge validation.

---

## 🚀 How to Use

### **1️⃣ Setup & Make Executable**
Ensure the script has execution permissions:

```sh
chmod +x validate_merges.sh
```

---

### **2️⃣ Run the Script**
Execute:

```sh
./validate_merges.sh
```

---

### **3️⃣ Monitor Logs**
Check the JSON log file for results:

```sh
cat output/operation_log.json | jq .
```

---

## ⚙️ Configuration

Modify the following variables inside `validate_merges.sh` if needed:

| Variable           | Description                                   | Default Value      |
|--------------------|----------------------------------------------|--------------------|
| `DEVELOP_BRANCH`  | Base branch for comparison                   | `"develop"`       |
| `TARGET_BRANCH`   | Temporary branch for testing merges          | `"S9_development"` |
| `DATE_THRESHOLD`  | Only check branches updated **after** this date | `"2025-01-13"`  |
| `OUTPUT_DIR`      | Directory where logs are stored               | `"output"`        |
| `LOG_FILE`        | JSON file storing validation results          | `"output/operation_log.json"` |

---

## 📂 File Structure

```
📂 project-root
 ├── 📄 validate_merges.sh    # Main script
 ├── 📂 output/               # Stores logs
 │   ├── operation_log.json   # Merge validation report
 ├── 📄 README.md             # Documentation (this file)
```

---

## 📊 Expected Output

The script generates a **JSON report** like this:

```json
{
  "execution_timestamp": "2025-01-19T12:45:00Z",
  "branches": [
    {
      "name": "feature/payment-processing",
      "status": "SUCCESS",
      "last_commit_date": "2025-01-15T09:30:00Z",
      "conflict_files": "",
      "message": "Branch can be merged cleanly"
    },
    {
      "name": "feature/user-auth",
      "status": "CONFLICT",
      "last_commit_date": "2025-01-14T14:10:00Z",
      "conflict_files": "lib/auth.dart,lib/main.dart",
      "message": "Merge conflict detected"
    }
  ],
  "summary": {
    "total_branches": 2,
    "conflict_count": 1,
    "successful_merges": 1
  }
}
```

---

## 🛠️ Troubleshooting

❌ **Permission Denied?**  
✅ Run:  
```sh
chmod +x validate_merges.sh
```

❌ **No branches detected?**  
✅ Ensure there are branches **not merged** into `develop`.

❌ **Unexpected conflicts?**  
✅ Inspect `operation_log.json` to see which files are causing issues.



## 📄 License

This project is open-source and available under the **MIT License**.

