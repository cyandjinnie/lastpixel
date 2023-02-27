// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract LastPixel {
    uint256 public timeBank;
    uint256 public colorBank;
    int8[10][10] public colorByCell;
    address public lastPainter;
    address[10][10] painterByCell;
    uint256 lastFee = 0.01 ether;
    bool init = false;
    mapping(address => int256) public cellsPaintedBy;

    uint256 public lastPaintTime;
    uint256 paintBlockedUntil = 0;
    uint256 colorBankSplitRewardLastCall = 0;

    function calcNewFee() private {
        uint256 newFee = (lastFee * 103) / 100;
        lastFee = newFee;
    }

    function getFee() public view returns (uint256) {
        return lastFee;
    }

    function getPainterByCell(uint8 x, uint8 y) public view returns (address) {
        require(x < 10, "x out of bounds");
        require(y < 10, "y out of bounds");
        return painterByCell[x][y];
    }

    function paint(
        uint8 x,
        uint8 y,
        int8 color
    ) public payable {
        uint256 fee = lastFee;
        require(msg.value >= fee, "give me money");
        require(x < 10, "x out of bounds");
        require(y < 10, "y out of bounds");
        require(0 <= color && color <= 7, "color must be in range [0, 7]");
        require(
            block.timestamp > paintBlockedUntil,
            "painting is blocked by color bank grab"
        );

        init = true;

        // Util for color bank rewards
        address oldPainter = painterByCell[x][y];
        if (oldPainter != address(0)) {
            if (cellsPaintedBy[oldPainter] > 0) {
                cellsPaintedBy[oldPainter] -= 1;
            }
        }
        cellsPaintedBy[msg.sender] += 1;

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
        require(
            block.timestamp - lastPaintTime > 10 minutes,
            "10 minute delay not finished"
        );
        require(msg.sender == lastPainter, "you are not the last painter");

        uint256 amount = timeBank;
        timeBank = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "transfer failed");
    }

    function fieldPaintedInOneColor() public view returns (bool) {
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

    function triggerColorBankSplit() public {
        require(init, "game not initialized");
        require(
            fieldPaintedInOneColor(),
            "not all cells are painted with one color"
        );
        require(cellsPaintedBy[msg.sender] > 0, "must be a participant");

        colorBankSplitRewardLastCall = block.timestamp + 5 minutes;
        paintBlockedUntil = block.timestamp + 5 minutes;
    }

    function colorBankSplitActive() private view returns (bool) {
        return block.timestamp <= colorBankSplitRewardLastCall;
    }

    function grabColorBankReward() public payable {
        require(init, "game not initialized");
        require(colorBank > 0, "color bank is drained");
        require(
            colorBankSplitActive(),
            "color bank split is not active, consider calling 'triggerColorBankSplit'"
        );
        int256 cellsPaintedBySender = cellsPaintedBy[msg.sender];
        require(cellsPaintedBySender > 0, "you have 0 reward");
        require(cellsPaintedBySender <= 100, "impossible");

        cellsPaintedBy[msg.sender] = 0;
        uint256 reward = (colorBank * uint256(cellsPaintedBySender)) / 100;
        colorBank -= reward;

        (bool success, ) = msg.sender.call{value: reward}("");
        require(success, "transfer failed");
    }
}
