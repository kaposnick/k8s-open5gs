#!/usr/bin/env python3
# -*- coding: utf-8 -*-

#
# SPDX-License-Identifier: GPL-3.0
#
# GNU Radio Python Flow Graph
# Title: Intra Handover Flowgraph
# GNU Radio version: 3.8.2.0

from distutils.version import StrictVersion

# if __name__ == '__main__':
#     import ctypes
#     import sys

from gnuradio import gr
from gnuradio.filter import firdes
import sys
import signal
from argparse import ArgumentParser
from gnuradio.eng_arg import eng_float, intx
from gnuradio import eng_notation
from gnuradio import zeromq
from PyQt5 import Qt
# from gnuradio import qtgui


RANGE_START_PORTS_UE = 30000
RANGE_START_PORTS_ENB = 35000

class intra_enb(gr.top_block, Qt.QWidget):

    def __init__(self, num_of_enbs, num_of_ues):
        gr.top_block.__init__(self, "Intra Handover Flowgraph")
        Qt.QWidget.__init__(self)

        if (num_of_enbs <= 0):
            raise Exception("Num of enbs must be positive")

        num_of_ues_pes_enb = int(num_of_ues / num_of_enbs)
        remainder_of_ues = num_of_ues % num_of_enbs

        ue_port = int(RANGE_START_PORTS_UE)
        enb_port = int(RANGE_START_PORTS_ENB)
        
        for enb_index in range(num_of_enbs):
            print("--- Setting eNB with index " + str(enb_index) + " ---")

            enb_ues = num_of_ues_pes_enb
            if (remainder_of_ues > 0):
                enb_ues += 1
                remainder_of_ues -= 1

            for ue_index in range(enb_ues):
                result = "Success"
                try:
                    ue_tx_port = zeromq.req_source(gr.sizeof_gr_complex, 1, 'tcp://localhost:' + str(ue_port), 100, False, -1)
                    ue_rx_port = zeromq.rep_sink(gr.sizeof_gr_complex, 1, 'tcp://*:' + str(ue_port + 1), 100, False, -1)
                    ue_port += 2

                    enb_tx_port = zeromq.req_source(gr.sizeof_gr_complex, 1, 'tcp://localhost:' + str(enb_port), 100, False, -1)
                    enb_rx_port = zeromq.rep_sink(gr.sizeof_gr_complex, 1, 'tcp://*:' + str(enb_port + 1), 100, False, -1)
                    enb_port += 2

                    self.connect((ue_tx_port, 0), (enb_rx_port, 0))
                    self.connect((enb_tx_port, 0), (ue_rx_port, 0))
                except Exception as e:
                    result = "Fail: " + str(e)
                finally:
                    ue_index = str(enb_index) + "_" + str(ue_index)
                    print("Connecting UE with index " + ue_index + ": " + result)



def main(top_block_cls=intra_enb, options=None):

    if StrictVersion("4.5.0") <= StrictVersion(Qt.qVersion()) < StrictVersion("5.0.0"):
        style = gr.prefs().get_string('qtgui', 'style', 'raster')
        Qt.QApplication.setGraphicsSystem(style)
    qapp = Qt.QApplication(sys.argv)

    cmd_line_args = sys.argv[1:]
    if (len(cmd_line_args) != 2):
        raise Exception("You have to pass exactly 2 command line arguments")

    num_of_enbs = int(cmd_line_args[0])
    num_of_ues =  int(cmd_line_args[1])

    tb = top_block_cls(num_of_enbs, num_of_ues)

    tb.start()
    tb.show()

    def sig_handler(sig=None, frame=None):
        Qt.QApplication.quit()

    signal.signal(signal.SIGINT, sig_handler)
    signal.signal(signal.SIGTERM, sig_handler)

    def quitting():
        tb.stop()
        tb.wait()

    qapp.aboutToQuit.connect(quitting)
    qapp.exec_()

if __name__ == '__main__':
    main()
