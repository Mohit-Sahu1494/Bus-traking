let ioInstance = null;

function setIo(io) {
  ioInstance = io;
}

function getIo() {
  return ioInstance;
}

function emitCampus(event, payload) {
  if (!ioInstance) return;
  ioInstance.to('campus').emit(event, payload);
}

function emitBus(busId, event, payload) {
  if (!ioInstance) return;
  ioInstance.to(`bus:${busId}`).emit(event, payload);
  ioInstance.to('campus').emit(event, payload);
}

function emitUser(userId, event, payload) {
  if (!ioInstance) return;
  ioInstance.to(`user:${userId}`).emit(event, payload);
}

module.exports = { setIo, getIo, emitCampus, emitBus, emitUser };
