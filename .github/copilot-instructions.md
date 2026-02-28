# MyRecords AI Agent Instructions

This document guides AI coding agents to quickly become productive in the **MyRecords** Flutter project. It emphasizes **project-specific architecture, conventions, workflows, and integration patterns**.

---

## 1. Big Picture Architecture

- **Mobile-first Flutter app** with two primary modules:
  - **Academic** (V1 focus): exams, homework, monthly dues
  - **Regular** (future): medical and personal documents
- **Core layers:**
  - **Models** (`/lib/models`): `.rec` JSON-backed Dart objects
    - Example: `record.dart` defines fields for title, description, subject, date, marks, images, updatedAt
  - **Database Service** (`/lib/services/db_service.dart`): wraps `sqflite` for CRUD
  - **Screens** (`/lib/screens`): Dashboard, Add/Edit, Record Details
  - **Widgets** (`/lib/widgets`): reusable UI components
- **Data flow:**  
UI (screens/forms) ↔ Record model ↔ SQLite (local DB) ↔ optional .rec export ↔ Google Drive
- **Why this structure:**  
- SQLite provides **fast local queries**  
- `.rec` files serve as **portable backup/sync units**  
- Background sync uses `updatedAt` timestamps to avoid conflicts

---

## 2. Critical Workflows

- **Build & run**
```bash
flutter pub get
flutter run

- Default target: device/emulator
- Hot reload supported

Database inspection
- getDatabasesPath() defines local DB file path
- For desktop inspection: use DB Browser for SQLite or VS Code SQLite extension

Background sync (V1)
- Runs async after UI load
- Pull .rec files → decrypt → update SQLite
- Push pending local changes → encrypt → upload .rec files
- Use updatedAt for last-writer-wins conflict resolution

### 3. Project-Specific Conventions

**Record IDs**  
- Generated via `UniqueKey().toString()`  
- Must remain stable for `.rec` sync  

**Timestamps**  
- `createdAt` and `updatedAt` stored in ISO 8601 string format  
- Critical for sync logic  

**Images**  
- Stored as base64, serialized in `.rec` JSON  
- `.rec` files encrypt base64

**SQLite fields vs JSON**  
- JSON key names match model fields  
- Fields like `completed` or `syncPending` stored as INTEGER (0/1) in SQLite  

**Screen navigation**  
- `DashboardScreen → AddEditRecordScreen → RecordDetailsScreen`  
- `Navigator.push(...).then((_) => loadRecords())` is used to refresh after add/edit  

---

### 4. Integration Points & Dependencies

- **sqflite:** core local DB  
- **path_provider:** locate SQLite DB and local storage paths  
- **Google Drive API** (optional for V1): handles `.rec` sync  
- **JSON serialization:** use `jsonEncode(record.toJson())` and `Record.fromJson(jsonDecode(...))`  
- **Images:** local image picker/storage required; images are not stored inside SQLite, only referenced  

---

### 5. Patterns to Follow

**CRUD**  
- Always interact with SQLite first  
- Mark new/edited records as `syncPending = true` for later upload  

**Sync**  
- Background, async, non-blocking UI  
- Pull only updated/new `.rec` files  
- Push only pending local changes  

**UI Lists**  
- Always load from SQLite  
- Use `ListView.builder` and `FutureBuilder` for async DB calls  

**Forms**  
- Add/Edit uses same screen  
- Validate fields locally before inserting/updating DB  

---

### 6. Key Files / Directories to Reference

- `/lib/models/record.dart` → `.rec` schema + JSON serialization  
- `/lib/services/db_service.dart` → SQLite CRUD + `syncPending` flag  
- `/lib/screens/dashboard.dart` → main record list  
- `/lib/screens/add_edit.dart` → Add/Edit record form  
- `/lib/screens/record_details.dart` → view/delete/edit single record  
- `/lib/widgets` → reusable UI components  

---

### 7. AI Agent Notes

- Always read multiple files together to understand data flows: Model ↔ DB ↔ Screen  
- Use timestamps and `syncPending` logic when reasoning about edits/sync  
- Avoid assumptions about `.rec` content; always check `record.dart` for actual fields  
- For testing, consider creating sample SQLite records with dummy `.rec` JSON  

---

### 8. Optional / Future Considerations

- Multi-image support (already fielded in `images: List<String>`)  
- Encryption of `.rec` files  
- Drive background sync notifications  
- ORM migration (Floor/Drift) if queries become complex  

> **NOTICE:**  
> The current implementation is **Academic Module V1 only**.  
> This version includes:
> - **Exams**: track title, description, subject, date, max marks, obtained marks, and multiple images  
> - **Homework**: track title, description, subject, due date, completion status, and multiple images  
> - **Monthly dues**: track name, type, amount, and due date  
> - **Local storage**: SQLite is the source of truth; `.rec` files are used for portable backup/sync  
> - **UI**: Dashboard list, Add/Edit record form, Record Details view  
> - **Sync**: background async sync of `.rec` files is planned but optional in V1  
> 
> **Excluded in V1** (to be implemented later):
> - Regular module (medical and personal documents)  
> - Encryption of `.rec` files (optional later)  
> - Multi-drive/cloud integration beyond basic Google Drive  
> - Advanced ORM or complex query patterns  
> 
> AI agents should focus on **Academic CRUD, local SQLite workflows, `.rec` schema handling, and UI patterns**.