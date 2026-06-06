// src/services/scheduler/scheduler.service.js
import { pool } from '../../config/db.config.js';
import { pauseCampaign, restartCampaign } from './campaign.actions.js';
import { calculateDelay, formatDelay } from '../../utils/date.utils.js';
import { logger } from '../../utils/logger.js';

class SchedulerService {
  constructor() {
    this.jobs = new Map();
    this.activeCampaigns = new Set();
    this.scheduledTimes = new Map();
    logger.info('In-Memory Scheduler initialized');
  }

  /**
   * Планирует паузу и рестарт для кампании
   */
  async scheduleCampaign(campaign) {
    const { advertid, pause_time, restart_time, crmname } = campaign;

    const currentTimes = this.scheduledTimes.get(advertid);
    if (currentTimes?.pause_time === pause_time && currentTimes?.restart_time === restart_time) {
      return; // Время не изменилось
    }

    this.cancelCampaignJobs(advertid);

    await this.scheduleAction(advertid, 'pause', pause_time, crmname);
    await this.scheduleAction(advertid, 'restart', restart_time, crmname);

    this.scheduledTimes.set(advertid, { pause_time, restart_time });
    this.activeCampaigns.add(advertid);
  }

  /**
   * Планирует одно действие
   */
  async scheduleAction(campaignId, action, timeStr, crmname) {
    const delay = calculateDelay(timeStr);
    if (delay <= 0) return;

    const jobId = `${action}_${campaignId}`;
    const actionText = action === 'pause' ? 'остановка' : 'возобновление';

    logger.info(
      `⏰ Запланирована ${actionText} для ${campaignId} (${crmname}) в ${timeStr} (через ${formatDelay(delay)})`
    );

    const timer = setTimeout(async () => {
      try {
        if (action === 'pause') {
          await pauseCampaign(campaignId);
        } else {
          await restartCampaign(campaignId);
        }
        logger.info(`✅ ${actionText} для ${campaignId} выполнена`);
      } catch (error) {
        logger.error(`❌ Ошибка ${actionText} для ${campaignId}: ${error.message}`);
      }
    }, delay);

    this.jobs.set(jobId, timer);
  }

  /**
   * Отменяет все задачи для кампании
   */
  cancelCampaignJobs(campaignId) {
    for (const action of ['pause', 'restart']) {
      const jobId = `${action}_${campaignId}`;
      if (this.jobs.has(jobId)) {
        clearTimeout(this.jobs.get(jobId));
        this.jobs.delete(jobId);
      }
    }
    this.scheduledTimes.delete(campaignId);
    this.activeCampaigns.delete(campaignId);
  }

  /**
   * Получает список активных кампаний из БД
   */
  async getActiveCampaigns() {
    try {
      const { rows } = await pool.query(`
        SELECT advertid, crmname, pause_time, restart_time 
        FROM crm_headers 
        WHERE active = true
      `);
      return rows;
    } catch (error) {
      logger.error('Ошибка получения активных кампаний:', error.message);
      return [];
    }
  }

  /**
   * Восстанавливает задачи после перезапуска
   */
  async restoreScheduledJobs() {
    try {
      const campaigns = await this.getActiveCampaigns();
      for (const campaign of campaigns) {
        await this.scheduleCampaign(campaign);
      }
      logger.info(`Восстановлено ${campaigns.length} кампаний`);
    } catch (error) {
      logger.error('Ошибка восстановления задач:', error.message);
    }
  }
}

// Экспортируем класс, а не экземпляр — чтобы управлять инициализацией
export { SchedulerService };