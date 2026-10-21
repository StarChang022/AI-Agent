import sharp from 'sharp';

// 要產生 640px 寬度版本的 services 圖片
const servicesImages = [
  'business',
  'web',
  'app',
  'chatbot',
];

for (const name of servicesImages) {
  const src = `images/services/${name}-600.webp`;
  const out = `images/services/${name}-640.webp`;

  // 只指定寬度，等比縮放
  await sharp(src)
    .resize(640)
    .toFile(out);

  console.log(`generated: ${out}`);
}