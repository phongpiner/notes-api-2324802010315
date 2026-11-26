#!/usr/bin/env bash
# Chay trong thu muc goc cua repo: bash setup-bai3.sh
# Script chi ghi file ma nguon; KHONG tao .env va KHONG chua mat khau nao.
set -e
mkdir -p src/models src/routes scripts

# .env khong duoc commit
grep -qxF ".env" .gitignore 2>/dev/null || echo ".env" >> .gitignore

cat > .env.example <<'EOF'
MONGODB_URI=mongodb+srv://notes_app:<mat-khau>@<cluster>.mongodb.net/notes?retryWrites=true&w=majority
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_KEY=<khoa-secret>
EOF

cat > src/db.js <<'EOF'
const mongoose = require('mongoose');

async function connectDB(uri) {
  if (mongoose.connection.readyState === 1) return;
  await mongoose.connect(uri, { serverSelectionTimeoutMS: 5000 });
  console.log('Đã kết nối MongoDB Atlas');
}

module.exports = { connectDB };
EOF

cat > src/models/note.js <<'EOF'
const { Schema, model } = require('mongoose');

const noteSchema = new Schema(
  {
    title: { type: String, required: true, trim: true, maxlength: 200 },
    content: { type: String, default: '' },
    tags: { type: [String], default: [] },
    attachmentUrl: String,
    owner: String
  },
  { timestamps: true }
);

noteSchema.index({ tags: 1 });

module.exports = model('Note', noteSchema);
EOF

cat > src/storage.js <<'EOF'
const { createClient } = require('@supabase/supabase-js');

let client;
function bucket() {
  if (!client) {
    client = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_KEY);
  }
  return client.storage.from('attachments');
}

module.exports = { bucket };
EOF

cat > src/routes/notes.js <<'EOF'
const express = require('express');
const multer = require('multer');
const Note = require('../models/note');
const { bucket } = require('../storage');

const router = express.Router();
const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 2 * 1024 * 1024 } // 2 MB
});

router.get('/', async (req, res) => {
  const filter = req.query.tag ? { tags: String(req.query.tag) } : {};
  const notes = await Note.find(filter).sort({ createdAt: -1 }).limit(50);
  res.json(notes);
});

router.get('/:id', async (req, res) => {
  const note = await Note.findById(req.params.id);
  if (!note) return res.status(404).json({ error: 'Không tìm thấy ghi chú' });
  res.json(note);
});

router.post('/', async (req, res) => {
  const { title, content, tags } = req.body ?? {};
  const note = await Note.create({ title, content, tags });
  res.status(201).json(note);
});

router.put('/:id', async (req, res) => {
  const { title, content, tags } = req.body ?? {};
  const note = await Note.findByIdAndUpdate(
    req.params.id,
    { title, content, tags },
    { new: true, runValidators: true }
  );
  if (!note) return res.status(404).json({ error: 'Không tìm thấy ghi chú' });
  res.json(note);
});

router.delete('/:id', async (req, res) => {
  const note = await Note.findByIdAndDelete(req.params.id);
  if (!note) return res.status(404).json({ error: 'Không tìm thấy ghi chú' });
  res.status(204).end();
});

router.post('/:id/attachment', upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'Thiếu tệp ở trường "file"' });
  const note = await Note.findById(req.params.id);
  if (!note) return res.status(404).json({ error: 'Không tìm thấy ghi chú' });

  const safeName = req.file.originalname.normalize('NFD').replace(/[^\w.-]/g, '_');
  const path = `${note._id}/${Date.now()}-${safeName}`;
  const { error } = await bucket().upload(path, req.file.buffer, {
    contentType: req.file.mimetype
  });
  if (error) throw error;

  note.attachmentUrl = bucket().getPublicUrl(path).data.publicUrl;
  await note.save();
  res.json(note);
});

module.exports = router;
EOF

# app.js: giu route GET / cua bai 1, them router /notes va middleware loi
cat > src/app.js <<'EOF'
const express = require('express');
const os = require('os');
const notesRouter = require('./routes/notes');

const app = express();
app.use(express.json());

app.get('/', (req, res) => {
  res.json({
    message: 'Xin chào từ đám mây!',
    host: os.hostname(),
    platform: `${os.type()} ${os.release()}`,
    cpus: os.cpus().length,
    memoryGB: Number((os.totalmem() / 1024 ** 3).toFixed(1)),
    uptimeSec: Math.round(os.uptime()),
    time: new Date().toISOString()
  });
});

app.use('/notes', notesRouter);

app.use((err, req, res, next) => {
  console.error(err);
  const clientError = ['ValidationError', 'CastError'].includes(err.name)
    || err.code === 'LIMIT_FILE_SIZE';
  res.status(clientError ? 400 : 500).json({ error: err.message });
});

module.exports = app;
EOF

cat > src/server.js <<'EOF'
require('dotenv').config();
const app = require('./app');
const { connectDB } = require('./db');

const PORT = process.env.PORT || 3000;

connectDB(process.env.MONGODB_URI)
  .then(() => app.listen(PORT, () => console.log(`API đang chạy tại cổng ${PORT}`)))
  .catch((err) => {
    console.error('Không kết nối được cơ sở dữ liệu:', err.message);
    process.exit(1);
  });
EOF

cat > scripts/seed.js <<'EOF'
require('dotenv').config();
const mongoose = require('mongoose');
const Note = require('../src/models/note');

const TAGS = ['cloud', 'docker', 'nosql', 'security', 'devops', 'java', 'web'];

(async () => {
  await mongoose.connect(process.env.MONGODB_URI);
  await Note.deleteMany({ owner: 'seed' });
  const docs = Array.from({ length: 2000 }, (_, i) => ({
    title: `Ghi chú mẫu ${i + 1}`,
    content: 'Dữ liệu thử nghiệm',
    tags: [TAGS[i % 7], TAGS[(i * 3) % 7]],
    owner: 'seed'
  }));
  await Note.insertMany(docs);
  console.log(`Đã chèn ${docs.length} ghi chú`);
  await mongoose.disconnect();
})();
EOF

cat > scripts/explain.js <<'EOF'
require('dotenv').config();
const mongoose = require('mongoose');
const Note = require('../src/models/note');

const pick = (r) => (Array.isArray(r) ? r[0] : r).executionStats;

(async () => {
  await mongoose.connect(process.env.MONGODB_URI);
  await Note.syncIndexes();
  const scan = pick(await Note.find({ tags: 'docker' }).hint({ $natural: 1 }).explain('executionStats'));
  const idx = pick(await Note.find({ tags: 'docker' }).explain('executionStats'));
  console.table({
    'Quét toàn bộ': { docsExamined: scan.totalDocsExamined, returned: scan.nReturned, ms: scan.executionTimeMillis },
    'Dùng chỉ mục': { docsExamined: idx.totalDocsExamined, returned: idx.nReturned, ms: idx.executionTimeMillis }
  });
  await mongoose.disconnect();
})();
EOF

echo "Da ghi xong cac file Bai 3. Buoc tiep theo: npm install mongoose dotenv multer @supabase/supabase-js"
