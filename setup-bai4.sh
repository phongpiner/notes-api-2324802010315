#!/usr/bin/env bash
# Chay trong thu muc goc cua repo SAU KHI da lam xong Bai 3: bash setup-bai4.sh
# Script chi ghi file ma nguon; khong chua bi mat nao.
set -e
mkdir -p src/middleware src/models src/routes

cat > src/models/user.js <<'EOF'
const { Schema, model } = require('mongoose');

const userSchema = new Schema(
  {
    email: { type: String, required: true, unique: true, lowercase: true, trim: true },
    passwordHash: { type: String, required: true }
  },
  { timestamps: true }
);

module.exports = model('User', userSchema);
EOF

cat > src/routes/auth.js <<'EOF'
const express = require('express');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/user');

const router = express.Router();

// Chỉ chấp nhận chuỗi: chặn việc gửi đối tượng như {"$gt": ""} vào truy vấn
function readCredentials(body) {
  const { email, password } = body ?? {};
  if (typeof email !== 'string' || typeof password !== 'string') return null;
  if (!/^\S+@\S+\.\S+$/.test(email) || password.length < 8) return null;
  return { email: email.toLowerCase().trim(), password };
}

router.post('/register', async (req, res) => {
  const cred = readCredentials(req.body);
  if (!cred) return res.status(400).json({ error: 'Cần email hợp lệ và mật khẩu từ 8 ký tự' });
  if (await User.exists({ email: cred.email })) {
    return res.status(409).json({ error: 'Email đã được đăng ký' });
  }
  const passwordHash = await bcrypt.hash(cred.password, 10);
  const user = await User.create({ email: cred.email, passwordHash });
  res.status(201).json({ id: user._id, email: user.email });
});

router.post('/login', async (req, res) => {
  const cred = readCredentials(req.body);
  const user = cred && (await User.findOne({ email: cred.email }));
  const ok = user && (await bcrypt.compare(cred.password, user.passwordHash));
  if (!ok) return res.status(401).json({ error: 'Sai email hoặc mật khẩu' });

  const token = jwt.sign(
    { sub: user._id.toString(), email: user.email },
    process.env.JWT_SECRET,
    { expiresIn: '1h' }
  );
  res.json({ token });
});

module.exports = router;
EOF

cat > src/middleware/auth.js <<'EOF'
const jwt = require('jsonwebtoken');

module.exports = function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: 'Thiếu token' });
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch {
    res.status(401).json({ error: 'Token không hợp lệ hoặc đã hết hạn' });
  }
};
EOF

# notes.js: moi thao tac deu loc theo owner = req.user.sub
cat > src/routes/notes.js <<'EOF'
const express = require('express');
const multer = require('multer');
const Note = require('../models/note');
const { bucket } = require('../storage');
const requireAuth = require('../middleware/auth');

const router = express.Router();
router.use(requireAuth);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 2 * 1024 * 1024 } // 2 MB
});

router.get('/', async (req, res) => {
  const filter = { owner: req.user.sub };
  if (req.query.tag) filter.tags = String(req.query.tag);
  const notes = await Note.find(filter).sort({ createdAt: -1 }).limit(50);
  res.json(notes);
});

router.get('/:id', async (req, res) => {
  const note = await Note.findOne({ _id: req.params.id, owner: req.user.sub });
  if (!note) return res.status(404).json({ error: 'Không tìm thấy ghi chú' });
  res.json(note);
});

router.post('/', async (req, res) => {
  const { title, content, tags } = req.body ?? {};
  const note = await Note.create({ title, content, tags, owner: req.user.sub });
  res.status(201).json(note);
});

router.put('/:id', async (req, res) => {
  const { title, content, tags } = req.body ?? {};
  const note = await Note.findOneAndUpdate(
    { _id: req.params.id, owner: req.user.sub },
    { title, content, tags },
    { new: true, runValidators: true }
  );
  if (!note) return res.status(404).json({ error: 'Không tìm thấy ghi chú' });
  res.json(note);
});

router.delete('/:id', async (req, res) => {
  const note = await Note.findOneAndDelete({ _id: req.params.id, owner: req.user.sub });
  if (!note) return res.status(404).json({ error: 'Không tìm thấy ghi chú' });
  res.status(204).end();
});

router.post('/:id/attachment', upload.single('file'), async (req, res) => {
  if (!req.file) return res.status(400).json({ error: 'Thiếu tệp ở trường "file"' });
  const note = await Note.findOne({ _id: req.params.id, owner: req.user.sub });
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

cat > src/app.js <<'EOF'
const express = require('express');
const os = require('os');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const mongoose = require('mongoose');
const notesRouter = require('./routes/notes');
const authRouter = require('./routes/auth');

mongoose.set('sanitizeFilter', true); // lớp phòng thủ thứ hai chống NoSQL injection

const app = express();
app.set('trust proxy', 1);            // Codespaces và Vercel đứng sau proxy
app.use(helmet());                    // các header bảo mật HTTP
app.use(express.json({ limit: '100kb' }));

app.use('/auth', rateLimit({ windowMs: 15 * 60 * 1000, limit: 20 }), authRouter);

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

echo "Da ghi xong cac file Bai 4. Buoc tiep theo: npm install bcryptjs jsonwebtoken helmet express-rate-limit"
