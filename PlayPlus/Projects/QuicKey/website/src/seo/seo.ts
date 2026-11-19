import { computed } from 'vue'
import { useHead } from '@unhead/vue'
import { useRoute, type RouteLocationNormalizedLoaded } from 'vue-router'
import { faqItems } from '../data/faq'
import { posts } from '../data/posts'
import { pageSeo } from './pages'
import { SITE_DEFAULT_DESCRIPTION, SITE_LOCALE, SITE_NAME, absoluteUrl } from './site'

/** 依路由組出結構化資料（JSON-LD）。內容需與頁面可見文字一致。 */
function buildJsonLd(to: RouteLocationNormalizedLoaded, url: string, title: string, description: string): object[] {
  const org = {
    '@type': 'Organization',
    name: SITE_NAME,
    legalName: '普魯士國際有限公司',
    url: absoluteUrl('/'),
    logo: absoluteUrl('/brand/logo-horizontal.svg'),
    email: 'service@playplus.com.tw',
    contactPoint: {
      '@type': 'ContactPoint',
      contactType: 'customer service',
      email: 'service@playplus.com.tw',
      availableLanguage: 'zh-TW',
    },
    address: {
      '@type': 'PostalAddress',
      streetAddress: '忠孝東路四段270號7樓',
      addressLocality: '台北市大安區',
      addressCountry: 'TW',
    },
  }

  if (to.name === 'home') {
    return [
      org,
      { '@context': 'https://schema.org', '@type': 'WebSite', name: SITE_NAME, url: absoluteUrl('/'), inLanguage: 'zh-TW' },
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

type MetaTag = { name: string; content: string } | { property: string; content: string }

/**
 * 依路由組出 <head> 內容：title、description、robots、canonical、OG、Twitter 與 JSON-LD。
 * 建置時寫進每一頁的靜態 HTML，瀏覽器切換頁面時再由 @unhead/vue 更新。
 */
export function seoHead(to: RouteLocationNormalizedLoaded) {
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

  const meta: MetaTag[] = [
    { name: 'description', content: description },
    { name: 'robots', content: noindex ? 'noindex, nofollow' : 'index, follow' },
  ]
  // 不建立索引的頁面不輸出 canonical、OG、Twitter 與結構化資料
  if (noindex) return { title: fullTitle, meta }

  const ogImage = absoluteUrl('/og-image.png')
  meta.push(
    { property: 'og:site_name', content: SITE_NAME },
    { property: 'og:locale', content: SITE_LOCALE },
    { property: 'og:type', content: isPost ? 'article' : 'website' },
    { property: 'og:title', content: seoTitle },
    { property: 'og:description', content: description },
    { property: 'og:url', content: url },
    { property: 'og:image', content: ogImage },
    { property: 'og:image:width', content: '1200' },
    { property: 'og:image:height', content: '630' },
    { name: 'twitter:card', content: 'summary_large_image' },
    { name: 'twitter:image', content: ogImage },
    { name: 'twitter:title', content: seoTitle },
    { name: 'twitter:description', content: description },
  )

  return {
    title: fullTitle,
    meta,
    link: [{ rel: 'canonical', href: url }],
    script: [
      {
        id: 'seo-jsonld',
        type: 'application/ld+json',
        innerHTML: JSON.stringify(buildJsonLd(to, url, pageTitle, description)),
      },
    ],
  }
}

/** 在 App.vue 呼叫一次：依目前路由設定 <head>，切換頁面時自動更新 */
export function useSeo() {
  const route = useRoute()
  useHead(computed(() => seoHead(route)))
}
