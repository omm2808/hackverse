/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  transpilePackages: [
    '@fit-odyssey/api-client',
    '@fit-odyssey/config',
    '@fit-odyssey/shared-types',
    '@fit-odyssey/validation',
  ],
};

module.exports = nextConfig;
