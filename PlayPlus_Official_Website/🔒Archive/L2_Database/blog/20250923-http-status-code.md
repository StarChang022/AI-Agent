# Head Editor

**id**: 20250923-http-status-code
**title**: 網頁 404 是什麼？完整整理 200、301、404、500 等常見 HTTP 狀態碼懶人包
**description**: 有時候會發生網頁無法瀏覽的狀況，你得知道 200、301、404、500 這些 HTTP 狀態碼是什麼，快速排查原因與採取對應做法。
**keywords**: HTTP 狀態碼, HTTP Status Code, 404 是什麼, 500 伺服器錯誤, 301 轉址, 網站錯誤代碼, HTTP 錯誤原因, 網站維運懶人包
**tags**: 其他
**date**: 2025/09/23

---

# Content Editor

<div class="content column gap-frame-half">
	<div class="column">
		<div class="summary-box background-skin p-3 radius-6 my-4 text-start">
			<h4 class="mb-2 fs-6">HTTP 狀態碼核心重點</h4>
			<ul class="mb-0 p-0 list-unstyled">
				<li>✅ <strong>200 成功：</strong> 伺服器成功處理要求，網頁正常運作與擷取。</li>
				<li>✅ <strong>301 永久移動：</strong> 網址已永久轉址到新位置，對 SEO 權重轉移最重要。</li>
				<li>✅ <strong>404 找不到：</strong> 伺服器找不到要求的網頁，通常是網址錯誤或內容已被移除。</li>
				<li>✅ <strong>500 內部伺服器錯誤：</strong> 伺服器端發生錯誤，需網站管理員排除系統問題。</li>
			</ul>
		</div>
		<p>有時候會發生網頁無法瀏覽的狀況，頁面上會寫著「這個網頁無法正常運作」之類的文字，下方再帶有狀態碼，如 HTTP ERROR 401 或 HTTP ERROR 500 等等的。HTTP ERROR 後面那串 xxx 就是所謂的狀態碼，表示網頁運作發生的狀況。</p>
		<p>如果你僅是瀏覽者，關閉頁面就沒事了，但如果你是網站經營者，就要知道分別代表什麼含義唷。</p>
	</div>
	<div class="column">
		<h2 class="inside">100 暫時回應</h2>
		<table class="table table-striped">
		<thead>
				<tr>
					<th class="code">代碼</th>
					<th class="event">名稱</th>
					<th>說明</th>
				</tr>
			</thead>
			<tbody>
				<tr>
					<td>100</td>
					<td>繼續</td>
					<td>要求者應當繼續此要求。伺服器傳回此代碼，指出已收到某個要求的第一部分，正等候其餘部分。</td>
				</tr>
				<tr>
					<td>101</td>
					<td>切換通訊協定</td>
					<td>要求者已請求伺服器切換通訊協定，伺服器正在確認即將進行切換。</td>
				</tr>
			</tbody>
		</table>
	</div>
	<div class="column">
		<h2 class="inside">200 成功</h2>
		<table class="table table-striped">
		<thead>
				<tr>
					<th class="code">代碼</th>
					<th class="event">名稱</th>
					<th>說明</th>
				</tr>
			</thead>
			<tbody>
				<tr>
					<td>200</td>
					<td>成功</td>
					<td>伺服器已成功處理該要求。一般而言，這代表伺服器已提供所要求的網頁。如果你在 robots.txt 檔案中看到此狀態，即表示 GoogleBot 已成功擷取該網頁。</td>
				</tr>
				<tr>
					<td>201</td>
					<td>已建立</td>
					<td>該要求已成功完成，伺服器已建立新的資源。</td>
				</tr>
				<tr>
					<td>202</td>
					<td>已接受</td>
					<td>伺服器已接受該要求，但尚未處理。</td>
				</tr>
				<tr>
					<td>203</td>
					<td>非授權資訊</td>
					<td>伺服器成功處理該要求，但正在傳回可能來自另一來源的資訊。</td>
				</tr>
				<tr>
					<td>204</td>
					<td>無內容</td>
					<td>伺服器已成功處理該要求，但沒有傳回任何內容。</td>
				</tr>
				<tr>
					<td>205</td>
					<td>重設內容</td>
					<td>伺服器已成功處理該要求，但沒有傳回任何內容。與 204 回應不同，此回應需要要求者重設文件視圖。（例如清除表單以輸入新資料）</td>
				</tr>
				<tr>
					<td>206</td>
					<td>部分內</td>
					<td>伺服器已成功處理部分 GET 要求。</td>
				</tr>
			</tbody>
		</table>
	</div>
	<div class="column">
		<h2 class="inside">300 已重新導向</h2>
		<table class="table table-striped">
		<thead>
				<tr>
					<th class="code">代碼</th>
					<th class="event">名稱</th>
					<th>說明</th>
				</tr>
			</thead>
			<tbody>
				<tr>
					<td>300</td>
					<td>多重選擇</td>
					<td>根據該要求，伺服器可採取數種動作。伺服器可能會根據要求者（使用者代理程式）選擇一個動作，或者可能列出清單供要求者選擇一個動作。</td>
				</tr>
				<tr>
					<td>301</td>
					<td>永久移動</td>
					<td>這是我們常聽到的 301 轉址。要求的網頁已永久移到新位置。當伺服器傳回此回應（作為對 GET 或 HEAD 要求的回應）時，會自動將要求者導向新位置。你應該此用此代碼讓 GoogleBot 知道某個網頁或網站已永久移至新位置。</td>
				</tr>
				<tr>
					<td>302</td>
					<td>暫時移動</td>
					<td>伺服器目前正在對來自不同位置的網頁回應該要求，但是要求者應該繼續使用原位置發出以後的要求。此代碼類似於回應 GET 或 HEAD 要求的 301 代碼，會自動將要求者導向另一個位置，但是因為 GoogleBot 會繼續檢索原位置並為其建立索引，所以你不應該使用此代碼來告知 GoogleBot 某個網頁或網站已移除。</td>
				</tr>
				<tr>
					<td>303</td>
					<td>參閱其他位置</td>
					<td>當要求者應該對另一個位置發出單獨的 GET 要求以擷取回應時，伺服器會傳回此代碼，對於 HEAD 之外的所有要求，伺服器會自動導向其他位置。</td>
				</tr>
				<tr>
					<td>304</td>
					<td>未修改</td>
					<td>要求的網頁自上次要求後未經任何修改。當伺服器傳回此回應時，不會傳回該網頁內容。你應該設定伺服器傳回此回應，告知 GoogleBot 網頁自上次檢索後便未經修改，這樣可以節省頻寬和負載。</td>
				</tr>
				<tr>
					<td>305</td>
					<td>使用 Proxy</td>
					<td>要求者只能夠過 Proxy 進入要求的網頁。當伺服器傳回此回應時，也會指出要求者應該使用的 Proxy。</td>
				</tr>
				<tr>
					<td>307</td>
					<td>暫時重新導向</td>
					<td>伺服器目前正對來自不同位置的網頁回應該要求，要求者應該繼續使用原位置發出後的要求。此代碼類似於回應 GET 或 HEAD 要求的 301 代碼，會自動將要求者的向另一個位置，但是 GoogleBot 會繼續檢索原位置並為其建立索引，所以不應該使用此代碼來告知 GoogleBot 某網頁或網站已移除。</td>
				</tr>
			</tbody>
		</table>
	</div>
	<div class="column">
		<h2 class="inside">400 要求錯誤</h2>
		<table class="table table-striped">
		<thead>
				<tr>
					<th class="code">代碼</th>
					<th class="event">名稱</th>
					<th>說明</th>
				</tr>
			</thead>
			<tbody>
				<tr>
					<td>400</td>
					<td>不正確的要求</td>
					<td>伺服器無法解讀該要求的語法。</td>
				</tr>
				<tr>
					<td>401</td>
					<td>未授權</td>
					<td>該要求需要驗證。登入後，伺服器可能會對網頁傳回此回應。</td>
				</tr>
				<tr>
					<td>403</td>
					<td>禁止</td>
					<td>伺服器拒絕要求。如果看到 GoogleBot 嘗試檢索你網站的有效網頁時收到這個狀態碼，則可能是因為你的伺服器或主機封鎖 GoogleBot 存取權。你可以在 Google 網站管理員工具「檢索」標籤下的「檢索錯誤」看到此狀態碼。</td>
				</tr>
				<tr>
					<td>404</td>
					<td>找不到</td>
					<td>最常見的狀態碼。伺服器找不到要求的網頁，該要求是針對伺服器上不存在的網頁。例如你瀏覽 apple.com 時於網址後方隨意輸入 apple.com/1234，這不是該網站底下存在的網頁網址，則伺服器會傳回此回應。</td>
				</tr>
				<tr>
					<td>405</td>
					<td>不允許的方法</td>
					<td>不允許要求中指定的方法。</td>
				</tr>
				<tr>
					<td>406</td>
					<td>不接受</td>
					<td>無法以所要求的內容特性回應要求的網頁。</td>
				</tr>
				<tr>
					<td>407</td>
					<td>需要 Proxy 驗證</td>
					<td>此狀態碼類似於 401（未授權），但指定要求者必須使用 Proxy 進行驗證。當伺服器傳回此回應時，也會指出要求者應該使用的 Proxy。</td>
				</tr>
				<tr>
					<td>408</td>
					<td>要求逾時</td>
					<td>等候回應時，發生伺服器逾時。</td>
				</tr>
				<tr>
					<td>409</td>
					<td>衝突</td>
					<td>完成要求時，伺服器遇到衝突，伺服器必須在回應中包含衝突資訊。伺服器可能會在 PUT 要求與較早的某個要求相衝突時傳回此狀態碼作為回應，病提供這兩個要求之間的差異清單。</td>
				</tr>
				<tr>
					<td>410</td>
					<td>已移除</td>
					<td>要求的資源已永久移除。此代碼類似於 404，「資源曾經存在但現在已不復存在」的情況下，有時會使用 410 取代 404 而使用。如果資源已永久移動，你應該使用 301 指定新位置。</td>
				</tr>
				<tr>
					<td>411</td>
					<td>需要長度</td>
					<td>伺服器不接受不含有效內容長度不標頭欄位的要求。</td>
				</tr>
				<tr>
					<td>412</td>
					<td>前提失敗</td>
					<td>伺服器未滿足要求者所要求的其中一個前提。</td>
				</tr>
				<tr>
					<td>413</td>
					<td>要求實體太大</td>
					<td>伺服器無法處理要求，因為要求過於龐大。</td>
				</tr>
				<tr>
					<td>414</td>
					<td>要求的 URI 太長</td>
					<td>要求的 URI（通常指網址）過長，伺服器無法處理。</td>
				</tr>
				<tr>
					<td>415</td>
					<td>不支援的媒體類型</td>
					<td>要求的格式不受要求的網頁支援。</td>
				</tr>
				<tr>
					<td>416</td>
					<td>要求的範圍無法使用</td>
					<td>要求的範圍在該網頁上無法使用。</td>
				</tr>
				<tr>
					<td>417</td>
					<td>預期失敗</td>
					<td>伺服器無法達到預期要求標題欄位的條件。</td>
				</tr>
			</tbody>
		</table>
	</div>
	<div class="column">
		<h2 class="inside">500 伺服器錯誤</h2>
		<table class="table table-striped">
		<thead>
				<tr>
					<th class="code">代碼</th>
					<th class="event">名稱</th>
					<th>說明</th>
				</tr>
			</thead>
			<tbody>
				<tr>
					<td>500</td>
					<td>內部伺服器錯誤</td>
					<td>伺服器遭遇錯誤，無法完成要求。</td>
				</tr>
				<tr>
					<td>501</td>
					<td>未提供</td>
					<td>伺服器不具備完成要求所需的功能。例如當伺服器無法識別要求方式。</td>
				</tr>
				<tr>
					<td>502</td>
					<td>不正確的閘道</td>
					<td>伺服器當成閘道或 Proxy 使用，接收到來自上游伺服器的無效回應。</td>
				</tr>
				<tr>
					<td>503</td>
					<td>服務無法使用</td>
					<td>伺服器目前暫時無法使用，因為超載貨維護之故而關閉。這種情況通常屬於暫時性。</td>
				</tr>
				<tr>
					<td>504</td>
					<td>閘道逾時</td>
					<td>伺服器當成閘道或 Proxy 使用，而且未接收到來自上游伺服器的即時回應。</td>
				</tr>
				<tr>
					<td>505</td>
					<td>不支援 HTTP 版本</td>
					<td>伺服器不支援要求裡面所用的 HTTP 通訊協定版本。</td>
				</tr>
			</tbody>
		</table>
	</div>
	<div class="column">
		<h2 class="inside">結尾</h2>
		<p>如果你正在經營網站，建議要記住正確處理狀態碼，才知道該怎麼第一時間解決問題。忘記的話怎麼辦？再回來這裡查詢吧！</p>
	</div>
</div>