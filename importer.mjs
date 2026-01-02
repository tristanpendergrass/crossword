import fs from "fs";

const args = process.argv.slice(2);
if (args.length !== 1) {
  console.error("Usage: node importer.mjs <puzzle-date>");
  process.exit(1);
}

const puzzleDate = args[0];
if (!puzzleDate.match(/^\d\d\d\d-\d\d-\d\d$/)) {
  console.error('Puzzle date must have format "YYYY-MM-DD"');
  process.exit(1);
}

const puzzleRequest = await fetch(
  `https://www.nytimes.com/svc/crosswords/v6/puzzle/daily/${puzzleDate}.json`,
  {
    headers: {
      // NYT is a very secure website lol
      "X-Games-Auth-Bypass": "true",
    },
  },
);

if (puzzleRequest.status !== 200) {
  console.error(
    `NYT responded with error code ${puzzleRequest.status}: ${puzzleRequest.statusText}\nDid you enter the date correctly?`,
  );
  process.exit(1);
}

const puzzleInfo = await puzzleRequest.json();

if (puzzleInfo.body.length !== 1) {
  throw new Error("Expected exactly one body element");
}

const body = puzzleInfo.body[0];
const dimensions = body.dimensions;

const CellTypes = {
  normal: 1,
  circle: 2,
  highlight: 3,
};
const ALLOWED_CELL_TYPES = Object.values(CellTypes);

const originalCells = body.cells;
const puzzle = [];
const solution = [];
for (let row = 0; row < dimensions.height; row++) {
  const puzzleRow = [];
  const solutionRow = [];
  for (let column = 0; column < dimensions.width; column++) {
    const cell = originalCells[row * dimensions.width + column];
    const isBlock = !cell.answer;
    const isAnswerStart = !!cell.label;
    const isCircled = cell.type === CellTypes.circle;
    const isHighlighted = cell.type === CellTypes.highlight;

    if (!isBlock && !ALLOWED_CELL_TYPES.includes(cell.type)) {
      throw new Error("Unsupported cell type " + JSON.stringify(cell));
    }

    const cellValue = isBlock ? "#" : isAnswerStart ? cell.label : "0";
    puzzleRow.push(
      isCircled || isHighlighted
        ? {
            cell: cellValue,
            style: {
              // Passing undefined here when the fields are not needed to
              // exclude them from the final JSON output
              shapebg: isCircled ? "circle" : undefined,
              highlight: isHighlighted ? true : undefined,
            },
          }
        : cellValue,
    );
    solutionRow.push(isBlock ? "#" : cell.answer);
  }

  puzzle.push(puzzleRow);
  solution.push(solutionRow);
}

const clues = {
  Across: [],
  Down: [],
};

for (const clue of body.clues) {
  if (clue.text.length !== 1 || !clue.text[0].plain) {
    throw new Error("Unkown clue text format " + JSON.parse(clue));
  }

  const formattedClue = { number: clue.label, clue: clue.text[0].plain };

  if (clue.direction === "Across") {
    clues.Across.push(formattedClue);
  } else {
    clues.Down.push(formattedClue);
  }
}

const ipuzFields = {
  version: "http://ipuz.org/v2",
  kind: ["http://ipuz.org/crossword#1"],
  dimensions: dimensions,
  clues,
  puzzle,
  solution,
  title: "NYT Crossword",
  copyright: puzzleInfo.copyright,
  url: puzzleInfo.relatedContent.url,
  editor: puzzleInfo.editor,
  // Seems unlikely for there to be more than two authors
  author: puzzleInfo.constructors.join(" & "),
  date: puzzleInfo.publicationDate,
};

if (!fs.existsSync("puzzles/")) {
  fs.mkdirSync("puzzles/");
}

const filePath = `puzzles/${puzzleDate}.ipuz`;

const fileContents = JSON.stringify(ipuzFields, null, 2);
fs.writeFileSync(filePath, fileContents);
console.log(`Wrote ${filePath}`);

console.log("Uploading to squares.io...");

const formData = new FormData();

// This appears to be the default value when uploading via the UI
formData.append("data", '{"options":{}}');
formData.append("puz", fileContents);
formData.append("v", "2");

const response = await fetch("https://squares.io/api/1/puzzle", {
  method: "POST",
  body: formData,
});

if (!response.ok) {
  console.error("Failed to upload puzzle: " + response.statusText);
  process.exit(1);
}

const pid = (await response.json()).pids[0];

console.log(`Puzzle uploaded! View it at https://squares.io/solve/${pid}`);
