// src/services/scheduler/campaign.worker.js
import { Worker } from 'bullmq';
import redisConfig from '../../config/redis.config.js';    
import { pauseCampaign, restartCampaign } from './campaign.actions.js';
import { pool } from '../../../config/db.config.js';
import { logger } from '../../utils/logger.js';

export class CampaignWorker {
  constructor(queueName) {
    this.worker = new Worker(queueName, this.executeJob.bind(this), {
      connection: redisConfig,
      concurrency: 5,
      limiter: {
        max: 30,
        duration: 1000
      }
    });
    
    this.setupEventListeners();
  }

  async executeJob(job) {
    const { campaignId, action } = job.data;
    
    switch (action) {
      case 'pause':
        return await pauseCampaign(campaignId);
      case 'restart':
        return await restartCampaign(campaignId);
      default:
        throw new Error(`Unknown action: ${action}`);
    }
  }

  setupEventListeners() {
    this.worker.on('completed', (job, result) => {
      const message = `Кампания ${job.data.campaignId}: ${job.data.action} выполнена`;
      logger.info(message);
      this.logToDB(job.data.campaignId, job.data.action, 'completed', message);
    });

    this.worker.on('failed', (job, error) => {
      const errorMessage = error.message || 'Unknown error';
      logger.error(`Job ${job.id} failed: ${errorMessage}`);
      this.logToDB(job.data.campaignId, job.data.action, 'failed', errorMessage);
    });
  }

  async logToDB(campaignId, action, status, message) {
    try {
      await pool.query(
        `INSERT INTO campaign_logs (campaign_id, action, status, message) 
         VALUES ($1, $2, $3, $4)`,
        [campaignId, action, status, message]
      );
    } catch (error) {
      logger.error('Failed to log to DB:', error.message);
    }
  }
}
