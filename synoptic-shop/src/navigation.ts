import { getPermalink} from './utils/permalinks';

export const headerData = {
  links: [
    {
      text: 'Products',
      links: [
        {
          text: 'Starter Kit',
          href: getPermalink('/products/starter-kit'),
        },
        {
          text: 'Synopticam',
          href: getPermalink('/products/synopticam'),
        },
        {
          text: 'Inference Credits',
          href: getPermalink('/products/inference-credits'),
        },
      ],
    },
    {
      text: 'Company',
      links: [
        {
          text: 'About',
          href: getPermalink('/about'),
        },
        {
          text: 'Contact',
          href: getPermalink('/contact'),
        },
        {
          text: 'Terms',
          href: getPermalink('/terms'),
        },
        {
          text: 'Privacy',
          href: getPermalink('/privacy'),
        },
      ],
    },
    {
      text: 'Resources',
      links: [
        {
          text: 'Support',
          href: getPermalink('/support'),
        },
        {
          text: 'Newsletter',
          href: getPermalink('/newsletter'),
        },
      ],
    },
  ],
  actions: [{ text: 'Open App', href: 'https://app.synoptic.vision', target: '_blank' }],
};

export const footerData = {
  links: [
    {
      title: 'Products',
      links: [
        { text: 'Starter Kit', href: '/products/starter-kit' },
        { text: 'Synopticam', href: '/products/synopticam' },
        { text: 'Inference Credits', href: '/products/inference-credits' },
      ],
    },
    {
      title: 'Company',
      links: [
        { text: 'About', href: '/about' },
        { text: 'Contact', href: '/contact' },
        { text: 'Terms', href: '/terms' },
        { text: 'Privacy', href: '/privacy' },
      ],
    },
    {
      title: 'Resources',
      links: [
        { text: 'Support', href: '/support' },
        { text: 'Newsletter', href: '/newsletter' },
      ],
    },
    {
      title: 'Platform',
      links: [
        { text: 'Mobile App', href: 'https://app.synoptic.vision' },
        { text: 'API Documentation', href: '/docs' },
        { text: 'System Status', href: '/status' },
      ],
    },
  ],
  secondaryLinks: [
    { text: 'Terms', href: getPermalink('/terms') },
    { text: 'Privacy Policy', href: getPermalink('/privacy') },
  ],
  socialLinks: [
    { ariaLabel: 'X', icon: 'tabler:brand-x', href: '#' },
    { ariaLabel: 'LinkedIn', icon: 'tabler:brand-linkedin', href: '#' },
    { ariaLabel: 'GitHub', icon: 'tabler:brand-github', href: '#' },
  ],
  footNote: `
    <img class="w-5 h-5 md:w-6 md:h-6 md:-mt-0.5 bg-cover mr-1.5 rtl:mr-0 rtl:ml-1.5 float-left rtl:float-right rounded-sm" src="/favicon.ico" alt="Synoptic logo" loading="lazy"></img>
    Made by <a class="text-blue-600 underline dark:text-muted" href="https://synoptic.vision/">Synoptic</a> · All rights reserved.
  `,
};