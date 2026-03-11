import gulp from 'gulp';
import imagemin from 'gulp-imagemin';
import htmlmin from 'gulp-htmlmin';
import browserSync from 'browser-sync';
import cleanCSS from 'gulp-clean-css';
import uglify from 'gulp-uglify';
import replace from 'gulp-replace';
import rev from 'gulp-rev';
import revRewrite from 'gulp-rev-rewrite';
import fs from 'fs';
import path from 'path';
import { stream as criticalStream } from 'critical';
import terser from 'gulp-terser';
import purgecss from 'gulp-purgecss';
import puppeteer from 'puppeteer';

const { parallel, series } = gulp;
const bs = browserSync.create();

function minifyHTML() {
	return gulp.src([
		'./*.html',
		'./blog/**/*.html',
		'./services/**/*.html',
		'./portfolio/**/*.html',
	], { base: './', allowEmpty: true })  // 保持原有目錄結構
		.pipe(htmlmin({
			collapseWhitespace: true, // 移除多餘空白
			removeComments: true, // 移除註解
			removeOptionalTags: true,
			removeRedundantAttributes: true,
			removeScriptTypeAttributes: true,
			conservativeCollapse: true, // 保守的空白移除
			caseSensitive: true,
			preserveLineBreaks: false,       // 不保留換行
			removeEmptyAttributes: true,     // 移除空屬性
			sortAttributes: true,            // 排序屬性
			sortClassName: true,             // 排序 class 名稱
		}))
		.on('error', function(err) {
		console.error('HTML minify error:', err);
		this.emit('end'); // 防止整個流程中斷
	})
		.pipe(gulp.dest('./dist'));
}
/**
 * Generate and inline Critical CSS for key HTML pages.
 * Reads from dist and writes optimized HTML back to ./dist
 */
function generateCritical() {
	return gulp
		.src('dist/*.html')
		.pipe(
			criticalStream({
				base: 'dist/',
				inline: true,
				css: ['dist/style.css', 'dist/css/custom.css', 'dist/css/font-icons.css'],
				dimensions: [
					{ width: 375, height: 800 }, // mobile
					{ width: 768, height: 1024 }, // tablet
					{ width: 1300, height: 900 } // desktop
				],
				// 加上 Puppeteer 穩定性設定
				penthouse: {
					timeout: 60000, // 60 秒超時
					maxEmbeddedBase64Length: 1000,
					renderWaitTime: 500,
					blockJSRequests: true, // 阻擋 JS 請求提高穩定性
					// 以自訂方式啟動 Puppeteer，避免預設啟動問題
					puppeteer: {
						getBrowser: async () => {
							return puppeteer.launch({
								headless: true,
								args: [
									'--no-sandbox',
									'--disable-setuid-sandbox',
									'--disable-dev-shm-usage',
									'--disable-accelerated-2d-canvas',
									'--disable-gpu',
									'--window-size=1920,1080'
								]
							});
						}
					}
				},
				// 忽略錯誤繼續處理
				ignore: {
					atrule: ['@font-face', '@import'],
					rule: [/\.owl-/, /\.swiper-/, /\.animate/],
					decl: (node, value) => {
						return /url\(/.test(value) && !/data:/.test(value);
					}
				}
			})
		)
		.on('error', (err) => {
			console.error('Critical CSS Error:', err.message);
			// 不中斷流程，繼續處理
		})
		.pipe(gulp.dest('dist'));
}

// 產出帶 hash 的檔名 (指紋) 例如 custom-3f4a1c.css，避免手動 ?v=6
function revisionAssets() {
	return gulp.src([
		'./dist/style.css',
		'./dist/css/font-icons.css',
		'./dist/css/custom.css'
	], { base: './dist' })
		.pipe(rev()) // 產生檔案指紋(只有檔案內容有變動才會更新)
		.pipe(gulp.dest('./dist')) // 寫入新檔名
		.pipe(rev.manifest()) // 產生對應表
		.pipe(gulp.dest('./dist'));
}

// 將 dist 下 HTML 內的原始檔名改成指紋檔名
function rewriteHTML() {
	// 讀取 manifest 檔案
	const manifestPath = './dist/rev-manifest.json';
	if (!fs.existsSync(manifestPath)) {
		console.error('Rev manifest file not found:', manifestPath);
		return gulp.src('./dist/**/*.html');
	}

	const manifest = JSON.parse(fs.readFileSync(manifestPath, 'utf8'));

	let stream = gulp.src('./dist/**/*.html');

	// 替換每個 CSS 檔案的引用
	Object.keys(manifest).forEach(originalFile => {
		const hashedFile = manifest[originalFile];
		// 替換 href 引用 (包含 preload 和 stylesheet)
		stream = stream.pipe(replace(
			new RegExp(`href="${originalFile}"`, 'g'),
			`href="${hashedFile}"`
		));
		// 替換 noscript 中的引用
		stream = stream.pipe(replace(
			new RegExp(`href="([^"]*/)?"${originalFile.replace('/', '\\/')}"`, 'g'),
			`href="$1${hashedFile}"`
		));
	});

	return stream
		.on('error', function(err) {
			console.error('Rev rewrite error:', err.message);
			this.emit('end');
		})
		.pipe(gulp.dest('./dist'));
}

// 清理 dist 資料夾
function cleanDist(cb) {
	if (fs.existsSync('./dist')) {
		fs.rmSync('./dist', { recursive: true, force: true });
	}
	cb();
}

// 複製二進位檔案（圖片、字型）
function copyBinaryAssets() {
    return gulp.src([
        './images/**/*',
        './css/**/*.{woff,woff2,ttf,otf,eot,png,jpg,jpeg,gif,svg}'
    ], {
        encoding: false,  // 關鍵設定
        base: './'
    })
    .pipe(gulp.dest('./dist'));
}

// 複製文字檔案（CSS）
function copyCSSForCritical() {
    return gulp.src([
        './css/**/*.css',
        './style.css'
    ], { base: './' })
    .pipe(gulp.dest('./dist'));
}

// 複製並優化圖片到 dist
function copyImagesForCritical() {
    return gulp.src(['./images/**/*'], {
        encoding: false,    // ✅ 關鍵：不轉換編碼，保持二進位
        buffer: true        // ✅ 使用 buffer 模式處理
    })
    .pipe(gulp.dest('./dist/images'));
}

// 複製 JS 檔案
function copyJSFiles() {
	return gulp.src(['./js/**/*.js'], { base: './' })
		.pipe(gulp.dest('./dist'));
}

// 複製其他必要檔案
function copyOtherFiles() {
	return gulp.src([
		'./robots.txt',
		'./CNAME',
		'./public/**/*'
	], { allowEmpty: true })
		.pipe(gulp.dest('./dist'));
}



// 只對 dist/style.css 執行 PurgeCSS，保留常見動態 class
function purgeStyleCSS() {
	return gulp.src('dist/style.css', { allowEmpty: true })
		.pipe(purgecss({
			content: ['dist/**/*.html', 'dist/js/**/*.js'], //掃描的檔案
			safelist: {
				standard: [
					// 常見 UI 狀態
					'show', 'active', 'open', 'collapse', 'collapsing', 'in', 'modal-open',
					// 字型與圖示
					/^fa-/, /^icon-/,
					// 動畫/套件類別
					/^animate/, /^owl-/, /^swiper-/, /^slick-/, /^magnific-/,
				],
				greedy: [/data-/, /aria-/]
			}
		}))
		.pipe(gulp.dest('dist'));
}

// 壓縮 dist 內的 CSS（包含 Purge 後的 style.css）
function minifyCSS() {
	return gulp.src(['dist/**/*.css', '!dist/**/*.min.css'], { base: 'dist' })
		.pipe(cleanCSS({
			level: 2,
			inline: false, // 不 inline 本地 @import，避免 ?v= 造成找不到檔案
			rebase: false // 不重寫 url 路徑
		}))
		.pipe(gulp.dest('dist'));
}

// 以 Terser 壓縮 dist 內的 JS，略過 *.min.js
function minifyJS() {
	return gulp.src(['dist/js/**/*.js', '!dist/js/**/*.min.js'], { base: 'dist' })
		.pipe(terser())
		.pipe(gulp.dest('dist'));
}


// 修正 CSS 內 @import 路徑為 /css/icons/ 開頭，避免 404
function rewriteCSSImports() {
	return gulp.src(['dist/**/*.css'], { base: 'dist' })
		// icons/...  -> /css/icons/...
		.pipe(replace(/@import\s+url\((['\"]?)icons\//g, '@import url($1/css/icons/'))
		// css/icons/... (缺少開頭 /) -> /css/icons/...
		.pipe(replace(/@import\s+url\((['\"]?)css\/icons\//g, '@import url($1/css/icons/'))
		// dist/css/icons/... -> /css/icons/...
		.pipe(replace(/@import\s+url\((['\"]?)(?:\.\.\/)?dist\/css\/icons\//g, '@import url($1/css/icons/'))
		.pipe(gulp.dest('dist'));
}

// 修正 HTML 內 img 標籤的相對路徑為絕對路徑
function rewriteImagePaths() {
	return gulp.src(['dist/**/*.html'], { base: 'dist' })
		// images/... -> /images/...
		.pipe(replace(/(<img[^>]+src=["'])images\//g, '$1/images/'))
		// ./images/... -> /images/...
		.pipe(replace(/(<img[^>]+src=["'])\.\/images\//g, '$1/images/'))
		// ../images/... -> /images/...
		.pipe(replace(/(<img[^>]+src=["'])\.\.\/images\//g, '$1/images/'))
		// dist/images/... -> /images/...
		.pipe(replace(/(<img[^>]+src=["'])(?:\.\.\/)?dist\/images\//g, '$1/images/'))
		.on('error', function(err) {
			console.error('Image path rewrite error:', err.message);
			this.emit('end');
		})
		.pipe(gulp.dest('dist'));
}

// 完整建置流程
export const build = series(
	// 1. 清理舊的建置檔案
	cleanDist,

	// 2. 平行處理資源
	parallel(
		// CSS 相關處理
		copyBinaryAssets,    // 先處理二進位檔案
		copyCSSForCritical,  // 再處理 CSS
		// JS 處理
		copyJSFiles,
		// 圖片處理
		copyImagesForCritical,
		// 其他檔案處理
		copyOtherFiles
	),

	// 3. 處理 HTML (包含所有子資料夾)
	minifyHTML,

	// 4. 生成 Critical CSS
	generateCritical,

	// 5. Purge 與壓縮（CSS/JS）
	series(
		purgeStyleCSS,
		parallel(minifyCSS, minifyJS),
		parallel(rewriteCSSImports, rewriteImagePaths)
	),

	// 6. 產生資源指紋並更新引用
	series(
		revisionAssets,
		rewriteHTML
	)
);

export const htmlminify = minifyHTML;
export const revision = series(revisionAssets, rewriteHTML);
export const critical = generateCritical;
export { generateCritical, copyCSSForCritical };
export const minify = series(purgeStyleCSS, parallel(minifyCSS, minifyJS));
export const rewritecssimports = rewriteCSSImports;
export const rewriteimagepaths = rewriteImagePaths;