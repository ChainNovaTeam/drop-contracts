import {StandardMerkleTree} from "@openzeppelin/merkle-tree";
import fs from "fs";
import {expect} from "chai";

// address 101~110
const values = [
    ["0x0000000000000000000000000000000000000065"],
    ["0x0000000000000000000000000000000000000066"],
    ["0x0000000000000000000000000000000000000067"],
    ["0x0000000000000000000000000000000000000068"],
    ["0x0000000000000000000000000000000000000069"],
    ["0x000000000000000000000000000000000000006a"],
    ["0x000000000000000000000000000000000000006b"],
    ["0x000000000000000000000000000000000000006C"],
    ["0x000000000000000000000000000000000000006D"],
    ["0x000000000000000000000000000000000000006E"]
];

const exRoot = "0x7753ee10f91c40a4e2f0dcc8dc0bcc074a24ca8df608e50407af203b2b45befb"

describe("openzeppelin Merkle", function () {

    const tree = StandardMerkleTree.of(values, ["address"]);

    it("Merkle Root", async function () {
        expect(tree.root).eq(exRoot)
    })

    xit("Merkle dump write file", async function () {
        expect(tree.root).eq(exRoot)

        const directory = './temp';
        const filePath = `${directory}/tree.json`;
        const content = JSON.stringify(tree.dump());
        // 创建目录（如果不存在）
        if (!fs.existsSync(directory)) {
            fs.mkdirSync(directory);
        }

        // 写入文件
        fs.writeFileSync(filePath, content);
    })

    it("merkle log proof value", () => {
        for (const [i, v] of tree.entries()) {
            const proof = tree.getProof(i);
            console.log("------", i, "------");
            console.log("Value:", v);
            console.log("proof:", proof);
            console.log("-------------");
        }
    });

    it("merkle verify", () => {
        const leaf = 0;
        const proof = tree.getProof(leaf);
        console.log("proof 0:", proof);

        for (const [i, v] of tree.entries()) {
            expect(v).eq(values[i]);
        }

        const verify = tree.verify(leaf, proof);
        expect(verify).eq(true);
        console.log("verify 0:", verify);
    });

    it("merkle verify static", () => {
        const proof = [
            '0x0023f9f5bc869f8a01704930a5f32546cd410a1b423c29d8c67c83157f056d0d',
            '0x0149ef5591f2fdbbbe593f83970032c7624147c4b8221be345d66e248e439609',
            '0xeff6b3cec91dd677a36ea0563574ac79c0c1fea09bcbcc6289d893fc8e701a1e',
            '0xfb3c5a06a36e971b3f23ca37824439ce241afea1f132ccd6a79acb754c0af82b'
        ];

        const verify = tree.verify(0, proof);
        expect(verify).eq(true);
    })

})
