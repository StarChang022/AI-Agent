import type { RouteLocationNormalized } from 'vue-router'
import { faqItems } from '../data/faq'
import { posts } from '../data/posts'
import { pageSeo } from './pages'
import { SITE_DEFAULT_DESCRIPTION, SITE_LOCALE, SITE_NAME, absoluteUrl } from './site'

const JSONLD_ID = 'seo-jsonld'

function setMeta(attr: 'name' | 'property', key: string, content: string) {
  let el = document.head.querySelector<HTMLMetaElement>(`meta[${attr}="${key}"]`)
  if (!el) {
    el = document.createElement('meta')
    el.setAttribute(attr, key)
    document.head.appendChild(el)
  }
  el.setAttribute('content', content)
}

function removeEl(selector: string) {
  document.head.querySelector(selector)?.remove()
}

function setCanonical(href: string) {
  let el = document.head.querySelector<HTMLLinkElement>('link[rel="canonical"]')
  if (!el) {
    el = document.createElement('link')
    el.rel = 'canonical'
    document.head.appendChild(el)
  }
  el.href = href
}

function setJsonLd(data: object[]) {
  let el = document.getElementById(JSONLD_ID) as HTMLScriptElement | null
  if (!el) {
    el = document.createElement('script')
    el.type = 'application/ld+json'
    el.id = JSONLD_ID
    document.head.appendChild(el)
  }
  el.textContent = JSON.stringify(data)
}

/** 依路由組出結構化資料（JSON-LD）。內容需與頁面可見文字一致。 */
function buildJsonLd(to: RouteLocationNormalized, url: string, title: string, description: string): object[] {
  const org = {
    '@type': 'Organization',
    name: SITE_NAME,
    url: absoluteUrl('/'),
    logo: absoluteUrl('/brand/logo-horizontal.svg'),
  }

  if (to.name === 'home') {
    return [
      org,
      { '@context': 'https://schema.org', '@type': 'WebSite', name: SITE_NAME, url: absoluteUrl('/'), inLanguage: 'zh-TW' },
      {
        '@context': 'https://schema.org',
        '@type': 'SoftwareApplication',
        name: SITE_NAME,
        applicationCategory: 'BusinessApplication',
        operatingSystem: 'Web',
        description,
        url: absoluteUrl('/'),
      },
    ]
  }

  if (to.name === 'faq') {
    return [
      {
        '@context': 'https://schema.org',
        '@type': 'FAQPage',
        mainEntity: faqItems.map((item) => ({
          '@type': 'Question',
          name: item.q,
          acceptedAnswer: { '@type': 'Answer', text: item.a },
        })),
      },
    ]
  }

  const crumbs: { name: string; path: string }[] = [{ name: '首頁', path: '/' }]
  if (to.name === 'blog-post') {
    const post = posts.find((p) => p.slug === to.params.slug)
    crumbs.push({ name: '部落格', path: '/blog' })
    if (post) {
      crumbs.push({ name: post.title, path: `/blog/${post.slug}` })
      return [
        {
          '@context': 'https://schema.org',
          '@type': 'Article',
          headline: post.title,
          description: post.summary,
          datePublished: post.publishedAt,
          author: org,
          publisher: org,
          mainEntityOfPage: url,
          inLanguage: 'zh-TW',
        },
        breadcrumbs(crumbs),
      ]
    }
  } else if (to.path !== '/') {
    crumbs.push({ name: String(to.meta.title ?? title), path: to.path })
  }

  return to.name === 'not-found' ? [] : [breadcrumbs(crumbs)]
}

function breadcrumbs(items: { name: string; path: string }[]) {
  return {
    '@context': 'https://schema.org',
    '@type': 'BreadcrumbList',
    itemListElement: items.map((item, i) => ({
      '@type': 'ListItem',
      position: i + 1,
      name: item.name,
      item: absoluteUrl(item.path),
    })),
  }
}

/** 依目前路由更新 title、description、canonical、robots、OG 與 JSON-LD */
export function applySeo(to: RouteLocationNormalized) {
  const pageTitle = String(to.meta.title ?? SITE_NAME)
  const isPost = to.name === 'blog-post'
  const post = isPost ? posts.find((p) => p.slug === to.params.slug) : undefined
  // 文章頁的 <title> 使用文章標題；其他頁沿用路由標題
  const fullTitle = `${post?.title ?? pageTitle} ｜ ${SITE_NAME}`

  const description = post?.summary ?? pageSeo[String(to.name)]?.description ?? SITE_DEFAULT_DESCRIPTION
  const seoTitle = post?.title ?? pageTitle
  // canonical 不帶 query（例如部落格篩選、分頁），只保留路徑
  const url = absoluteUrl(to.path)
  const noindex = pageSeo[String(to.name)]?.noindex === true

  document.title = fullTitle
  setMeta('name', 'description', description)
  setMeta('name', 'robots', noindex ? 'noindex, nofollow' : 'index, follow')
  if (noindex) {
    // 不建立索引的頁面不輸出 canonical、og:url 與結構化資料
    removeEl('link[rel="canonical"]')
    removeEl(`#${JSONLD_ID}`)
    removeEl('meta[property="og:url"]')
    document.documentElement.dataset.seoReady = '1'
    return
  }
  setCanonical(url)

  setMeta('property', 'og:site_name', SITE_NAME)
  setMeta('property', 'og:locale', SITE_LOCALE)
  setMeta('property', 'og:type', isPost ? 'article' : 'website')
  setMeta('property', 'og:title', seoTitle)
  setMeta('property', 'og:description', description)
  setMeta('property', 'og:url', url)
  setMeta('name', 'twitter:card', 'summary')
  setMeta('name', 'twitter:title', seoTitle)
  setMeta('name', 'twitter:description', description)

  setJsonLd(buildJsonLd(to, url, pageTitle, description))
  document.documentElement.dataset.seoReady = '1'
}
