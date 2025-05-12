import { Worker } from 'bullmq';
import redisConfig from '../../config/redis.config.js';
import { pauseCampaign, restartCampaign } from './campaign.actions.js';

export class CampaignWorker {
    constructor(queueName) {
        this.worker = new Worker(queueName, this.executeJob.bind(this), {
            connection: redisConfig,
            concurrency: 5,
            limiter: {
                max: 30,
                duration: 1000 // 30 запросов в секунду
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
            console.log(`✅ ${result.status}`);
            this.logToDB(job.data.campaignId, job.name, 'completed', result.status);
        });

        this.worker.on('failed', (job, error) => {
            const errorMessage = error.message || 'Unknown error';
            console.error(`❌ Job ${job.id} failed: ${errorMessage}`);
            this.logToDB(job.data.campaignId, job.name, 'failed', errorMessage);
        });
    }

    async logToDB(campaignId, action, status, message) {
        // Ваша реализация логирования в БД
        // Пример:
        await pool.query(
            `INSERT INTO campaign_logs 
            (campaign_id, action, status, message) 
            VALUES ($1, $2, $3, $4)`,
            [campaignId, action, status, message]
        );
    }
}