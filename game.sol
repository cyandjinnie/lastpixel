// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract LastPixel {
    uint public timeBank;
    uint public colorBank;
    int8[10][10] public colorByCell;
    address public lastPainter;
    uint public lastPaintTime;
    address[10][10] painterByCell;
    uint lastFee = 0.01 ether;
    bool init = false;

    function calcNewFee() private {
        uint newFee = (lastFee * 103) / 100;
        lastFee = newFee;
    }

    function getFee() public view returns (uint) {
        return lastFee;
    }

    function getPainterByCell(uint8 x, uint8 y) public view returns (address) {
        require(x < 10, "x out of bounds");
        require(y < 10, "y out of bounds");
        return painterByCell[x][y];
    }

    function paint(uint8 x, uint8 y, int8 color) public payable {
        uint fee = lastFee;
        require(msg.value >= fee, "give me money");
        require(x < 10, "x out of bounds");
        require(y < 10, "y out of bounds");
        require(0 <= color && color <= 7, "color must be in range [0, 7]");

        init = true;

        colorByCell[x][y] = color;
        painterByCell[x][y] = msg.sender;
        timeBank += (msg.value * 8) / 10;
        colorBank += (msg.value * 2) / 10;
        lastPainter = msg.sender;
        lastPaintTime = block.timestamp;
        calcNewFee();
    }

    function grabTimeBank() public payable {
        require(init, "game not initialized");
        require(block.timestamp > lastPaintTime, "check for time warp failed");
        require(block.timestamp - lastPaintTime > 10 minutes, "10 minute delay not finished");
        require(msg.sender == lastPainter, "you are not the last painter");

        payable(msg.sender).transfer(timeBank);
        timeBank = 0;
    }

    function fieldPaintedInOneColor() private view returns (bool) {
        int8 color = colorByCell[0][0];
        for (uint8 i = 0; i < 10; i++) {
            for (uint8 j = 0; j < 10; j++) {
                if (colorByCell[i][j] != color) {
                    return false;
                }
            }
        }
        return true;
    }

    function grabColorBank() public payable {
        require(init, "game not initialized");
        require(colorBank > 0, "color bank is drained");
        require(fieldPaintedInOneColor(), "not all cells are painted with one color");

        uint cellsPaintedBySender = 0;
        for (uint8 i = 0; i < 10; i++) {
            for (uint8 j = 0; j < 10; j++) {
                if (painterByCell[i][j] == msg.sender) {
                    cellsPaintedBySender += 1;
                    painterByCell[i][j] = address(0);
                }
            }
        }

        uint reward = (colorBank * cellsPaintedBySender) / 100;
        payable(msg.sender).transfer(reward);
        colorBank -= reward;
    }
}