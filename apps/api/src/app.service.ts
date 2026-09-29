import { Injectable } from '@nestjs/common';
import { APP_CONFIG } from '@fit-odyssey/config';

@Injectable()
export class AppService {
  getHealthStatus() {
    return {
      status: 'ok',
      service: APP_CONFIG.NAME,
      version: APP_CONFIG.VERSION,
      timestamp: new Date().toISOString(),
    };
  }
}
