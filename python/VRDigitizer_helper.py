import sys
import time
import openvr
#import pyquaternion
import numpy as np
import pprint
import socket
import ctypes
import winsound
import threading
import logging

logging.basicConfig(level=logging.INFO)

def getTranslationFromMatrix(mat):
    xyz = []
    for i in range(3):
        xyz.append(mat[i][3])
    xyz[2] = -xyz[2]
    return xyz

def getQuaternionFromMatrix(mat):
    tmp = np.asarray(mat.m)
    tmp = tmp[0:3,0:3] # cut out XYZ
    #pprint(np.matmul(tmp,np.transpose(tmp))) # this should approximately equal identity
    quat = pyquaternion.Quaternion(matrix=tmp) # may need to edit pyquaternion initialization code to increase orthogonality tolerance by a factor of 10
    tmp = quat.elements
    tmp[1],tmp[2] = -tmp[1], -tmp[2]
    return tmp

def getVectorTransformFromMatrix(mat):
    tmp = np.asarray(mat.m)
    # change from OpenVR to MATLAB coordinate system
    tmp[[1,2], :] = tmp[[2,1], :]
    tmp[:,[1,2]] = tmp[:,[2,1]]
    tmp[1,:] = -1.0*tmp[1,:]
    tmp[:,1] = -1.0*tmp[:,1]
    tmp = tmp.flatten().tolist()
    return tmp

def parseControllerState(state):
    pressedButtons = state.ulButtonPressed
    touchedButtons = state.ulButtonTouched

    parsedState = {}
    parsedState['Menu_Pressed'] = pressedButtons & 1 << openvr.k_EButton_ApplicationMenu > 0
    parsedState['Trigger_Pressed'] = pressedButtons & 1 << openvr.k_EButton_SteamVR_Trigger > 0
    parsedState['Grip_Pressed'] = pressedButtons & 1 << openvr.k_EButton_Grip > 0

    # TODO: dynamically detect rather than hardcoding axis indices
    touchpadAxisIndex = 0
    triggerAxisIndex = 1

    parsedState['Trigger_Touched'] = state.rAxis[triggerAxisIndex].x > 0.1

    parsedState['Up_Touched'] = False
    parsedState['Up_Pressed'] = False
    parsedState['Down_Touched'] = False
    parsedState['Down_Pressed'] = False
    parsedState['Left_Pressed'] = False
    parsedState['Left_Touched'] = False
    parsedState['Right_Pressed'] = False
    parsedState['Right_Touched'] = False

    if touchedButtons & 1 << openvr.k_EButton_SteamVR_Touchpad:
        isPressed = pressedButtons & 1 << openvr.k_EButton_SteamVR_Touchpad > 0
        axis = state.rAxis[touchpadAxisIndex]
        #print('Axis %d value: %f %f' % (touchpadAxisIndex, axis.x, axis.y))
        if axis.y > 0.7:
            parsedState['Up_Touched'] = True
            parsedState['Up_Pressed'] = isPressed
        elif axis.y < -0.7:
            parsedState['Down_Touched'] = True
            parsedState['Down_Pressed'] = isPressed
        if axis.x > 0.7:
            parsedState['Right_Touched'] = True
            parsedState['Right_Pressed'] = isPressed
        elif axis.x < -0.7:
            parsedState['Left_Touched'] = True
            parsedState['Left_Pressed'] = isPressed

    #pprint(parsedState)

    return parsedState

class ThreadedBeep(threading.Thread):
    def __init__(self,frequency, duration, delayBetweenReps = 100):
        super(ThreadedBeep, self).__init__()
        self.freq = frequency
        self.dur = duration
        self.delay = delayBetweenReps

        self.start()

    def run(self):
        for i in range(len(self.freq)):
            winsound.Beep(self.freq[i], self.dur[i])
            time.sleep(self.delay / 1000)

while True:
    try:
        openvr.init(openvr.VRApplication_Scene)
        break
    except openvr.OpenVRError as msg:
        logging.warning('Failed to init openvr: %s' % msg)
        time.sleep(1)
        logging.info('Retrying to init openvr')

sys = openvr.IVRSystem()

devKeyToIndex = {}
timeOfLastDeviceAssignmentUpdate = 0
trackerCount = 0
controllerCount = 0
hmdCount = 0
def updateDeviceAssignment():
    global devKeyToIndex
    global timeOfLastDeviceAssignmentUpdate
    global trackerCount
    global controllerCount
    global hmdCount
    prevDevKeyToIndex = devKeyToIndex

    if time.time() - timeOfLastDeviceAssignmentUpdate > 1:
        devKeyToIndex = {}
        trackerCount = 0
        controllerCount = 0
        hmdCount = 0
        for i in range(openvr.k_unMaxTrackedDeviceCount):
            devClass = sys.getTrackedDeviceClass(i)
            if devClass == openvr.TrackedDeviceClass_Controller:
                devKeyToIndex['Controller_%d' % controllerCount] = i
                controllerCount += 1
            elif devClass == openvr.TrackedDeviceClass_GenericTracker:
                devKeyToIndex['Tracker_%d' % trackerCount] = i
                trackerCount += 1
            elif devClass == openvr.TrackedDeviceClass_HMD:
                devKeyToIndex['HMD'] = i
                hmdCount += 1
            elif devClass == openvr.TrackedDeviceClass_Invalid:
                pass # do nothing
            elif devClass == openvr.TrackedDeviceClass_TrackingReference:
                pass # do nothing
            else:
                logging.info('Not using device %d due to unrecognized class' % i)

        timeOfLastDeviceAssignmentUpdate = time.time()

        if prevDevKeyToIndex != devKeyToIndex:
            logging.info('Updated device assignments:')
            logging.info(pprint.pformat(devKeyToIndex))

disableNetworking = False
doConvertToQuaternions = False

IP = '127.0.0.1'
port = 3947

doReinitConnection = True

poses_t = openvr.TrackedDevicePose_t * openvr.k_unMaxTrackedDeviceCount
poses = poses_t()
getPoseForDevices = []
s = None

while True:
    if doReinitConnection:
        if not disableNetworking:

            logging.info('Waiting to connect...')

            s = socket.socket()
            while True:
                try:
                    s.settimeout(0.1)
                    s.connect((IP, port))
                    break
                except socket.error as msg:
                    # print('retrying connect after error: %s' % msg)
                    s.close()
                    time.sleep(0.5)
                    s = socket.socket()
                    continue

            logging.info('Connected')

            s.settimeout(0.0) # shorten non-blocking timeout for receive attempts below

        doReinitConnection = False

    updateDeviceAssignment()

    sys.getDeviceToAbsoluteTrackingPose(openvr.TrackingUniverseStanding, 0, len(poses), poses)

    possiblePoseKeyIDs = {
        'Controller_0': 0,
        'Controller_1': 1,
        'Tracker_0':    2,
        'Tracker_1':    3,
        'HMD':          4}

    getPoseForDevices = []

    for iC in range(0,controllerCount):
        key = 'Controller_%d' % iC
        if key not in possiblePoseKeyIDs:
            logging.warning('Unrecognized key %s' % key)
            continue
        getPoseForDevices.append(key)

    for iT in range(0,trackerCount):
        key = 'Tracker_%d' % iT
        if key not in possiblePoseKeyIDs:
            logging.warning('Unrecognized key %s' % key)
            continue
        getPoseForDevices.append(key)

    if hmdCount > 0:
        key = 'HMD'
        if key not in possiblePoseKeyIDs:
            logging.warning('Unrecognized key %s' % key)
            continue
        getPoseForDevices.append(key)

    header = 0xFF54 + len(getPoseForDevices)

    header = (header >> 8) | (header << 8) # swap endianness manually

    if doConvertToQuaternions:
        XYZs = {}
        quats = {}
    else:
        transfs = {}

    for devKey in getPoseForDevices:
        if devKey in devKeyToIndex:
            devIndex = devKeyToIndex[devKey]
            pose = poses[devIndex]
            if pose.bPoseIsValid and pose.bDeviceIsConnected:
                if doConvertToQuaternions:
                    XYZs[devKey] = getTranslationFromMatrix(pose.mDeviceToAbsoluteTracking)
                    quats[devKey] = getQuaternionFromMatrix(pose.mDeviceToAbsoluteTracking)
                    #print('XYZQuat for %s: %s %s' % (devKey, XYZs[devKey], quats[devKey]))
                else:
                    transfs[devKey] = getVectorTransformFromMatrix(pose.mDeviceToAbsoluteTracking)
                continue

        #print('Device %s does not have valid pose' % devKey)

    getButtonsForDevice = 'Controller_0'
    devKey = getButtonsForDevice
    if devKey in devKeyToIndex:
        devIndex = devKeyToIndex[devKey]
        [isValid, controllerState] = sys.getControllerState(devIndex)
        if isValid:
            parsedState = parseControllerState(controllerState)
        else:
            logging.warning('Controller state not valid')
            parsedState = None
    else:
        logging.info('Controller for buttons not connected')
        parsedState = None


    buttonStates = 0
    if parsedState is not None:
        buttonStates |= parsedState['Trigger_Touched'] << 0
        buttonStates |= parsedState['Grip_Pressed'] << 1
        buttonStates |= parsedState['Menu_Pressed'] << 2
        buttonStates |= parsedState['Up_Touched'] << 3
        buttonStates |= parsedState['Up_Pressed'] << 4
        buttonStates |= parsedState['Down_Touched'] << 5
        buttonStates |= parsedState['Down_Pressed'] << 6
        buttonStates |= parsedState['Left_Touched'] << 7
        buttonStates |= parsedState['Left_Pressed'] << 8
        buttonStates |= parsedState['Right_Touched'] << 9
        buttonStates |= parsedState['Right_Pressed'] << 10


    if not disableNetworking:
        try:
            s.sendall(ctypes.c_uint16(header))

            s.sendall(ctypes.c_uint16(buttonStates))

            if doConvertToQuaternions:
                XYZArray = ctypes.c_float*3
                QuatArray = ctypes.c_float*4

                for devKey in getPoseForDevices:
                    s.sendall(ctypes.c_uint8(possiblePoseKeyIDs[devKey]))
                    if devKey in XYZs:
                        s.sendall(XYZArray(*XYZs[devKey]))
                        s.sendall(QuatArray(*quats[devKey]))
                    else:
                        s.sendall(XYZArray(0.0, 0.0, 0.0))
                        s.sendall(QuatArray(1.0, 0.0, 0.0, 0.0))
            else:
                TransfArray = ctypes.c_float*12
                for devKey in getPoseForDevices:
                    s.sendall(ctypes.c_uint8(possiblePoseKeyIDs[devKey]))
                    if devKey in transfs:
                        s.sendall(TransfArray(*transfs[devKey]))
                    else:
                        s.sendall(TransfArray(*([0.0]*12)))

            s.sendall(ctypes.c_uint16(0))

        except socket.error as msg:
            logging.info('Send socket error. Resetting connection.');
            doReinitConnection = True
            s.close()
            continue

        try:
            rxByte = s.recv(1)
            num = ord(rxByte)

            # unpack bit values
            audioCode = num & 0b011
            print('Audio code: %d' % audioCode)
            if audioCode == 0:
                pass # don't play audio
            elif audioCode == 1: # success
                ThreadedBeep((784,), (100,))
            elif audioCode == 2: # warning
                ThreadedBeep((440,), (200,))
            elif audioCode == 3: # error
                winsound.PlaySound('SystemExclamation',winsound.SND_ALIAS | winsound.SND_ASYNC)

            hapticStrength = (num >> 3) << 7

            devKey = 'Controller_0'
            if devKey in devKeyToIndex:
                devIndex = devKeyToIndex[devKey]
                logging.debug('Triggering haptic pulse with strength %d' % hapticStrength)
                sys.triggerHapticPulse(devIndex, 0, hapticStrength)

            logging.debug('Received: %s %d' % (rxByte, ord(rxByte)))
        except socket.error as msg:
            logging.debug('Receive socket error')
            pass # do nothing if receive failed

    time.sleep(0.05)

logging.error('Outside of while loop, about to terminate.')

openvr.shutdown()
