// Generates an ASCII visualization of farm_map_v2.tscn layout.
// Outputs to docs/farm_v2_layout.txt
const fs = require('fs');
const path = require('path');

const PROJECT_ROOT = path.resolve(__dirname, '..', '..');

// Build same as build_farm_v2.js
function buildGroundTiles() {
  const arr = [];
  for (let y = 0; y < 37; y++) {
    for (let x = 0; x < 50; x++) {
      const isFarmZone = (y >= 17 && y <= 35 && x >= 1 && x <= 36);
      const isPathCol = (x === 17 || x === 18);
      let ch = '.';
      if (isFarmZone && !isPathCol) ch = '#'; // dirt
      else if (isFarmZone && isPathCol) ch = ':'; // path grass
      else ch = ' '; // grass (blank for clarity)
      arr.push({ x, y, ch });
    }
  }
  return arr;
}

function buildDecorTiles() {
  const arr = [];
  for (let y = 0; y < 37; y++) {
    for (let x = 0; x < 50; x++) {
      let ch = '';
      if (y === 16 && x >= 1 && x <= 36) ch = '═'; // fence top
      else if (y === 36 && x >= 1 && x <= 36) ch = '═'; // fence bottom
      else if (x === 0 && y >= 17 && y <= 35) ch = '║'; // fence left
      else if (x === 37 && y >= 17 && y <= 35) ch = '║'; // fence right
      else if (y <= 14 && x >= 38 && x <= 46 && (x + y) % 3 === 0) ch = 'T'; // tree
      else if ([11, 12, 13].includes(y) && [29, 30, 31].includes(x) && (x + y) % 2 === 0) ch = 's'; // stone
      else if ([10, 11].includes(y) && [33, 34].includes(x)) ch = 'h'; // hay
      if (ch) arr.push({ x, y, ch });
    }
  }
  return arr;
}

const ground = buildGroundTiles();
const decor = buildDecorTiles();

// Build grid 50x37
let grid = Array.from({ length: 37 }, () => Array(50).fill('.'));
for (const c of ground) grid[c.y][c.x] = c.ch;
for (const d of decor) grid[d.y][d.x] = d.ch;

// Add house (a 13x12 box at rows 1-12, cols 1-12 with door at bottom)
for (let y = 1; y <= 12; y++) {
  for (let x = 1; x <= 12; x++) {
    if (y === 1 || y === 12 || x === 1 || x === 12) {
      grid[y][x] = '#'; // wall outline
    } else if (y >= 2 && y <= 11 && x >= 2 && x <= 11) {
      grid[y][x] = 'H'; // house interior (brown)
    }
  }
}
// Door opening at row 12-13, col 6
grid[12][6] = 'D'; grid[12][7] = 'D';

// ToHouse portal at (96, 232) ≈ col 6, row 14
grid[14][6] = 'E'; grid[14][7] = 'E';

// ToTown portal at (776, 300) ≈ col 48, row 18
grid[18][48] = 'T';

// Print grid with column header
let out = 'farm_map_v2 layout (50 cols × 37 rows, each tile = 16×16 px)\n';
out += '   ' + Array.from({ length: 50 }, (_, i) => (i % 10).toString()).join('') + '\n';
out += '   ' + '0'.repeat(50) + '\n';
for (let y = 0; y < 37; y++) {
  out += String(y).padStart(2, '0') + ' ' + grid[y].join('') + '\n';
}
out += '\n';
out += 'Legend:\n';
out += '  space  = grass\n';
out += '  .      = grass (variant)\n';
out += '  #      = dirt/soil (farm zone) OR house wall\n';
out += '  :      = path (vertical walkway)\n';
out += '  H      = house interior\n';
out += '  D      = house door\n';
out += '  ═      = wood fence (horizontal)\n';
out += '  ║      = wood fence (vertical)\n';
out += '  T      = tree\n';
out += '  s      = stone\n';
out += '  h      = hay bale\n';
out += '  E      = enter-house portal\n';
out += '  T      = to-town portal\n';
out += '\n';
out += 'Coordinates in pixels:\n';
out += '  Each tile = 16x16 px\n';
out += '  Map viewport: 800x600\n';
out += '  Farm zone: rows 17-35, cols 1-36 (22x19 tiles)\n';
out += '  House: rows 1-12, cols 1-12 (12x12 tiles, door at south)\n';
out += '  Yard: rows 1-15, cols 13-49 (right of house)\n';

const outDir = path.join(PROJECT_ROOT, 'docs');
if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'farm_v2_layout.txt'), out);
console.log('Wrote docs/farm_v2_layout.txt');
console.log(out);
