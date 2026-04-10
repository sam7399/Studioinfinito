const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const logger = require('../utils/logger');

class FileValidatorService {
  // File size limits in bytes
  static FILE_SIZE_LIMITS = {
    'documents': 5 * 1024 * 1024,    // 5 MB
    'images': 10 * 1024 * 1024,       // 10 MB
    'videos': 50 * 1024 * 1024,       // 50 MB
    'archives': 20 * 1024 * 1024      // 20 MB
  };

  // Allowed file types by category
  static ALLOWED_FILE_TYPES = {
    'documents': {
      mime: [
        'application/pdf',
        'application/msword',
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        'application/vnd.ms-excel',
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        'text/plain',
        'text/csv',
        'application/vnd.ms-powerpoint',
        'application/vnd.openxmlformats-officedocument.presentationml.presentation'
      ],
      extensions: ['.pdf', '.doc', '.docx', '.xls', '.xlsx', '.txt', '.csv', '.ppt', '.pptx']
    },
    'images': {
      mime: [
        'image/jpeg',
        'image/png',
        'image/gif',
        'image/webp',
        'image/svg+xml'
      ],
      extensions: ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.svg']
    },
    'videos': {
      mime: [
        'video/mp4',
        'video/quicktime',
        'video/x-msvideo',
        'video/webm'
      ],
      extensions: ['.mp4', '.mov', '.avi', '.webm']
    },
    'archives': {
      mime: [
        'application/zip',
        'application/x-rar-compressed',
        'application/x-7z-compressed',
        'application/gzip'
      ],
      extensions: ['.zip', '.rar', '.7z', '.gz', '.tar']
    }
  };

  /**
   * Get file category based on MIME type
   */
  static getFileCategory(mimeType) {
    for (const [category, types] of Object.entries(this.ALLOWED_FILE_TYPES)) {
      if (types.mime.includes(mimeType)) {
        return category;
      }
    }
    return null;
  }

  /**
   * Validate file size
   */
  static validateFileSize(file) {
    const category = this.getFileCategory(file.mimetype);
    
    if (!category) {
      return {
        valid: false,
        error: `File type ${file.mimetype} is not allowed`
      };
    }

    const maxSize = this.FILE_SIZE_LIMITS[category];
    if (file.size > maxSize) {
      const maxSizeMB = maxSize / (1024 * 1024);
      return {
        valid: false,
        error: `File size exceeds ${maxSizeMB}MB limit for ${category}`
      };
    }

    return { valid: true };
  }

  /**
   * Validate file type/extension
   */
  static validateFileType(file) {
    const ext = path.extname(file.originalname).toLowerCase();
    const category = this.getFileCategory(file.mimetype);

    if (!category) {
      return {
        valid: false,
        error: `File type not supported`
      };
    }

    // Check extension matches MIME type
    const allowedExts = this.ALLOWED_FILE_TYPES[category].extensions;
    if (!allowedExts.includes(ext)) {
      return {
        valid: false,
        error: `File extension ${ext} is not allowed for ${category}`
      };
    }

    return { valid: true, category };
  }

  /**
   * Basic malware/virus scan (checks for executable signatures)
   * Note: For production, integrate with ClamAV or similar service
   */
  static async scanForMalware(filePath) {
    try {
      const buffer = Buffer.alloc(512);
      const fd = fs.openSync(filePath, 'r');
      fs.readSync(fd, buffer, 0, 512);
      fs.closeSync(fd);

      // Check for common executable signatures
      const maliciousSignatures = [
        Buffer.from([0x4D, 0x5A]), // MZ header (PE executables)
        Buffer.from([0x7F, 0x45, 0x4C, 0x46]), // ELF header (Linux executables)
        Buffer.from([0xFE, 0xED, 0xFA]) // Mach-O header (macOS executables)
      ];

      for (const sig of maliciousSignatures) {
        if (buffer.includes(sig)) {
          logger.warn(`Potential malware detected in file: ${filePath}`);
          return {
            safe: false,
            reason: 'Executable file detected'
          };
        }
      }

      // Additional checks for suspicious patterns
      const content = buffer.toString('utf-8', 0, Math.min(buffer.length, 512));
      if (content.includes('cmd.exe') || content.includes('/bin/bash') || content.includes('powershell')) {
        logger.warn(`Suspicious script content detected in file: ${filePath}`);
        return {
          safe: false,
          reason: 'Suspicious script content detected'
        };
      }

      return { safe: true };
    } catch (error) {
      logger.error('Error scanning file for malware:', error);
      // In case of error, we allow the file but log it
      return { safe: true, warning: 'Could not perform full scan' };
    }
  }

  /**
   * Generate unique filename with hash
   */
  static generateUniqueFilename(originalFilename) {
    const ext = path.extname(originalFilename);
    const hash = crypto.randomBytes(16).toString('hex');
    const timestamp = Date.now();
    return `${timestamp}-${hash}${ext}`;
  }

  /**
   * Generate file checksum (SHA-256)
   */
  static generateFileChecksum(filePath) {
    try {
      const fileBuffer = fs.readFileSync(filePath);
      const hashSum = crypto.createHash('sha256');
      hashSum.update(fileBuffer);
      return hashSum.digest('hex');
    } catch (error) {
      logger.error('Error generating checksum:', error);
      return null;
    }
  }

  /**
   * Validate and prepare file metadata
   */
  static async validateAndPrepareFile(file) {
    try {
      // Validate file type
      const typeValidation = this.validateFileType(file);
      if (!typeValidation.valid) {
        return {
          valid: false,
          error: typeValidation.error
        };
      }

      // Validate file size
      const sizeValidation = this.validateFileSize(file);
      if (!sizeValidation.valid) {
        return {
          valid: false,
          error: sizeValidation.error
        };
      }

      // Scan for malware (if file path is available)
      let malwareCheck = { safe: true };
      if (file.path) {
        malwareCheck = await this.scanForMalware(file.path);
        if (!malwareCheck.safe) {
          return {
            valid: false,
            error: `Security check failed: ${malwareCheck.reason}`
          };
        }
      }

      // Generate unique filename
      const uniqueFilename = this.generateUniqueFilename(file.originalname);

      // Generate checksum
      const checksum = file.path ? this.generateFileChecksum(file.path) : null;

      return {
        valid: true,
        metadata: {
          original_name: file.originalname,
          stored_name: uniqueFilename,
          mime_type: file.mimetype,
          file_size: file.size,
          file_category: typeValidation.category,
          checksum: checksum,
          uploaded_at: new Date(),
          validation_status: 'passed'
        }
      };
    } catch (error) {
      logger.error('Error validating and preparing file:', error);
      return {
        valid: false,
        error: 'File validation failed'
      };
    }
  }

  /**
   * Get file info for storage
   */
  static getFileInfo(file, storedFilename) {
    return {
      originalName: file.originalname,
      storedName: storedFilename,
      mimeType: file.mimetype,
      fileSize: file.size,
      category: this.getFileCategory(file.mimetype),
      uploadedAt: new Date()
    };
  }

  /**
   * Validate batch of files
   */
  static async validateBatch(files) {
    const results = [];

    for (const file of files) {
      const validation = await this.validateAndPrepareFile(file);
      results.push({
        filename: file.originalname,
        ...validation
      });
    }

    return results;
  }

  /**
   * Get size limit for category in human-readable format
   */
  static getSizeLimitForCategory(category) {
    const bytes = this.FILE_SIZE_LIMITS[category];
    if (!bytes) return null;
    return `${bytes / (1024 * 1024)} MB`;
  }

  /**
   * Get all allowed extensions
   */
  static getAllowedExtensions() {
    const extensions = new Set();
    for (const category of Object.values(this.ALLOWED_FILE_TYPES)) {
      category.extensions.forEach(ext => extensions.add(ext));
    }
    return Array.from(extensions);
  }
}

module.exports = FileValidatorService;
