const socketIO = require('socket.io');
const jwt = require('jsonwebtoken');
const config = require('./index');
const logger = require('../utils/logger');
const { User } = require('../models');

/**
 * Socket.io Configuration and Initialization
 */

// Track connected users (userId -> socketId mapping)
const connectedUsers = new Map();

/**
 * Initialize Socket.io with authentication and event handlers
 * @param {http.Server} server - HTTP server instance
 * @returns {socketIO.Server} Socket.io instance
 */
function initializeSocket(server) {
  const io = socketIO(server, {
    cors: {
      origin: (origin, callback) => {
        // Allow requests with no origin (Postman, etc.)
        if (!origin) return callback(null, true);

        // Allow any localhost origin in development
        if (config.nodeEnv === 'development' && /^http:\/\/localhost(:\d+)?$/.test(origin)) {
          return callback(null, true);
        }

        if (config.cors.origins.includes(origin)) {
          callback(null, true);
        } else {
          logger.warn(`Socket.io CORS blocked origin: ${origin}`);
          callback(new Error('Not allowed by CORS'));
        }
      },
      credentials: true,
      methods: ['GET', 'POST']
    },
    transports: ['websocket', 'polling']
  });

  /**
   * Middleware: Authenticate socket connection using JWT
   */
  io.use(async (socket, next) => {
    try {
      const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.split(' ')[1];

      if (!token) {
        return next(new Error('Authentication error: No token provided'));
      }

      // Verify JWT token
      const decoded = jwt.verify(token, config.jwt.secret);
      const user = await User.findByPk(decoded.id, {
        attributes: ['id', 'name', 'email', 'role', 'company_id', 'department_id']
      });

      if (!user) {
        return next(new Error('Authentication error: User not found'));
      }

      // Attach user info to socket for later use
      socket.user = user;
      socket.userId = user.id;

      logger.info(`Socket authentication successful for user: ${user.id}`);
      next();
    } catch (error) {
      logger.warn(`Socket authentication failed: ${error.message}`);
      next(new Error(`Authentication error: ${error.message}`));
    }
  });

  /**
   * Connection handler
   */
  io.on('connection', (socket) => {
    logger.info(`User connected - ID: ${socket.userId}, Socket ID: ${socket.id}`);

    // Store user connection
    connectedUsers.set(socket.userId, socket.id);

    // Join user to personal room (for private notifications)
    socket.join(`user:${socket.userId}`);

    // Join user to company room (for company-wide broadcasts)
    if (socket.user.company_id) {
      socket.join(`company:${socket.user.company_id}`);
    }

    // Join user to department room (for department notifications)
    if (socket.user.department_id) {
      socket.join(`dept:${socket.user.department_id}`);
    }

    /**
     * Handle disconnection
     */
    socket.on('disconnect', () => {
      logger.info(`User disconnected - ID: ${socket.userId}, Socket ID: ${socket.id}`);
      connectedUsers.delete(socket.userId);
    });

    /**
     * Handle custom ping/pong to keep connection alive
     */
    socket.on('ping', () => {
      socket.emit('pong');
    });

    /**
     * Handle subscription to additional rooms (if needed)
     */
    socket.on('subscribe', (data) => {
      try {
        const { room } = data;
        if (room && typeof room === 'string') {
          socket.join(room);
          logger.debug(`User ${socket.userId} subscribed to room: ${room}`);
        }
      } catch (error) {
        logger.error('Error subscribing to room', { error: error.message });
      }
    });

    /**
     * Handle unsubscription from rooms
     */
    socket.on('unsubscribe', (data) => {
      try {
        const { room } = data;
        if (room && typeof room === 'string') {
          socket.leave(room);
          logger.debug(`User ${socket.userId} unsubscribed from room: ${room}`);
        }
      } catch (error) {
        logger.error('Error unsubscribing from room', { error: error.message });
      }
    });

    /**
     * Handle errors
     */
    socket.on('error', (error) => {
      logger.error('Socket error', { error: error.message, userId: socket.userId });
    });
  });

  return io;
}

/**
 * Emit notification to a specific user
 * @param {socketIO.Server} io - Socket.io instance
 * @param {number} userId - User ID
 * @param {object} notification - Notification object
 */
function emitToUser(io, userId, notification) {
  io.to(`user:${userId}`).emit('notification:new', notification);
}

/**
 * Emit notification to multiple users
 * @param {socketIO.Server} io - Socket.io instance
 * @param {array} userIds - Array of user IDs
 * @param {object} notification - Notification object
 */
function emitToUsers(io, userIds, notification) {
  userIds.forEach(userId => {
    emitToUser(io, userId, notification);
  });
}

/**
 * Emit notification to a department
 * @param {socketIO.Server} io - Socket.io instance
 * @param {number} departmentId - Department ID
 * @param {object} notification - Notification object
 */
function emitToDepartment(io, departmentId, notification) {
  io.to(`dept:${departmentId}`).emit('notification:new', notification);
}

/**
 * Emit notification to a company
 * @param {socketIO.Server} io - Socket.io instance
 * @param {number} companyId - Company ID
 * @param {object} notification - Notification object
 */
function emitToCompany(io, companyId, notification) {
  io.to(`company:${companyId}`).emit('notification:new', notification);
}

/**
 * Emit task update to relevant users
 * @param {socketIO.Server} io - Socket.io instance
 * @param {object} update - Task update object {userId, taskId, action, data}
 */
function emitTaskUpdate(io, update) {
  const { userId, taskId, action, data } = update;
  io.to(`user:${userId}`).emit('task:update', {
    taskId,
    action,
    data,
    timestamp: new Date()
  });
}

/**
 * Get all connected users
 * @returns {object} Map of userId -> socketId
 */
function getConnectedUsers() {
  return new Map(connectedUsers);
}

/**
 * Check if a user is online
 * @param {number} userId - User ID
 * @returns {boolean} True if user is online
 */
function isUserOnline(userId) {
  return connectedUsers.has(userId);
}

module.exports = {
  initializeSocket,
  emitToUser,
  emitToUsers,
  emitToDepartment,
  emitToCompany,
  emitTaskUpdate,
  getConnectedUsers,
  isUserOnline
};
