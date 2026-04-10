const multer = require('multer');
const path = require('path');
const fs = require('fs');
const FileValidatorService = require('../services/fileValidatorService');

const uploadDir = path.join(__dirname, '../../uploads/tasks');
if (!fs.existsSync(uploadDir)) {
  fs.mkdirSync(uploadDir, { recursive: true });
}

const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    // Use FileValidatorService to generate unique filename
    const uniqueName = FileValidatorService.generateUniqueFilename(file.originalname);
    cb(null, uniqueName);
  }
});

const fileFilter = (req, file, cb) => {
  try {
    // Validate file type using FileValidatorService
    const typeValidation = FileValidatorService.validateFileType(file);
    if (!typeValidation.valid) {
      return cb(new Error(typeValidation.error), false);
    }
    cb(null, true);
  } catch (error) {
    cb(new Error('File validation failed'), false);
  }
};

// Get the maximum file size (largest allowed for any category)
const maxFileSize = Math.max(
  FileValidatorService.FILE_SIZE_LIMITS.documents,
  FileValidatorService.FILE_SIZE_LIMITS.images,
  FileValidatorService.FILE_SIZE_LIMITS.videos,
  FileValidatorService.FILE_SIZE_LIMITS.archives
);

const upload = multer({
  storage,
  fileFilter,
  limits: { fileSize: maxFileSize }
});

module.exports = upload;
