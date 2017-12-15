from slackclient import SlackClient
import urllib
import serial
import sys
import time
import re
from collections import deque
import math

COM_BAUD = 9600

def main():

    comport = input("Enter COM port name: ")


    ser = serial.Serial(comport, COM_BAUD, timeout = 0, parity=serial.PARITY_NONE, stopbits=serial.STOPBITS_ONE, xonxoff=1)

    ser.write(bytearray("g 1900\r\n", "UTF8"))

    curLine = ""

    gps_status = None

    last_rec_time = time.time() * 1000

    alerted = False
    landed_alerted = False
    launch_alerted = False

    gps_start = None

    last_message_check = time.time() * 1000
    MESSAGE_CHECK_ITER = 5000

    message = ""

    maximum_altitude = 0
    maximum_speed = 0

    guess = []

    # Loop here and read COM data
    while True:

        bs = ser.read().decode("ISO-8859-1")
        out = str(bs)
        if not out == '':
            if out == '\r':
                out = '\n'

        curLine += out

        if out == '\n':

            #We got a new line. Processing...
            if(curLine.lower().find("selected") != -1):
                m = re.search('.?(\d)',curLine)
                level = int(m.group(0))
                print("\n\nWe are on level {lvl}".format(lvl=level))

            if(curLine.lower().find("Enter the Code:") != -1):
                print("\n\nWe are entering a code now")


            curLine = ""
            # ser.write();

        sys.stdout.write(out)
        sys.stdout.flush()



if __name__ == '__main__':
    main()