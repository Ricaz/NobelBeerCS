#!node
import fs from 'fs';
import path from 'path';

// This script generates random history files for the last 3 days.

const historyDir = path.resolve(process.cwd(), '../../history');

if (!fs.existsSync(historyDir)) {
  fs.mkdirSync(historyDir, { recursive: true });
}

// Today is 2025-10-10
const today = new Date();

function getRandomInt(min, max) {
  min = Math.ceil(min);
  max = Math.floor(max);
  return Math.floor(Math.random() * (max - min + 1)) + min;
}

async function generateFiles() {
  console.log('Generating history files...');
  for (let i = 1; i <= 3; i++) {
    const day = new Date(today);
    day.setDate(day.getDate() - i);
    
    const numFiles = getRandomInt(3, 8);
    console.log(`Generating ${numFiles} files for ${day.toDateString()}`);

    for (let j = 0; j < numFiles; j++) {
      const randomHour = getRandomInt(0, 23);
      const randomMinute = getRandomInt(0, 59);
      const randomSecond = getRandomInt(0, 59);
      const randomMs = getRandomInt(0, 999);
      
      const fileDate = new Date(day);
      fileDate.setUTCHours(randomHour, randomMinute, randomSecond, randomMs);
      
      const startTime = fileDate.getTime();
      const endTime = startTime - getRandomInt(30 * 60 * 1000, 60 * 60 * 1000); // 30 to 60 minutes before

      const fileName = `${startTime}.json`;
      const filePath = path.join(historyDir, fileName);
      
      const data = {
        startTime,
        endTime,
        scores: [],
      };

      fs.writeFileSync(filePath, JSON.stringify(data, null, 2));
      console.log(`  -> Created ${fileName}`);
    }
  }
  console.log('Done.');
}

generateFiles().catch(console.error);
