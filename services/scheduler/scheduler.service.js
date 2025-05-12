//services/scheduler/scheduler.service.js
import { pool } from '../../General/globals.js';
import { pauseCampaign, restartCampaign } from './campaign.actions.js';
import { logMessage, sendlogTG } from '../../General/logger.js';

class SchedulerService {
  constructor() {
    this.jobs = new Map(); // Храним таймеры задач
    this.activeCampaigns = new Set(); // Отслеживаем активные кампании
    this.scheduledTimes = new Map(); // Храним запланированные времена {campaignId: {pause_time, restart_time}}
    console.log('In-Memory Scheduler initialized');
  }

  /**
   * Планирует операции паузы/рестарта для кампании
   */
  async scheduleCampaign(campaign) {
    const { advertid, pause_time, restart_time, crmname } = campaign;

    // Проверяем, изменилось ли время по сравнению с уже запланированным
    const currentTimes = this.scheduledTimes.get(advertid);
    if (currentTimes && 
        currentTimes.pause_time === pause_time && 
        currentTimes.restart_time === restart_time) {
      // Время не изменилось - ничего не делаем
      return;
    }

    // Отменяем существующие задачи для этой кампании
    this.cancelCampaignJobs(advertid);

    // Планируем новые задачи
    await this.scheduleCampaignAction(advertid, 'pause', pause_time, crmname);
    await this.scheduleCampaignAction(advertid, 'restart', restart_time, crmname);

    // Сохраняем запланированные времена
    this.scheduledTimes.set(advertid, { pause_time, restart_time });
    this.activeCampaigns.add(advertid);
  }


  /**
   * Планирует конкретное действие для кампании
   */
  async scheduleCampaignAction(campaignId, action, timeStr, crmname) {
    const delay = this.calculateDelay(timeStr);
    if (delay <= 0) return;

    const jobId = `${action}_${campaignId}`;
    
    const timer = setTimeout(async () => {
      try {
        let result;
        if (action === 'pause') {
          result = await pauseCampaign(campaignId);
        } else {
          result = await restartCampaign(campaignId);
        }

        if (result.success) {
          let loggingMessage = `✅ ${result.status}`;
          logMessage('scheduleCampaignAction', '1', loggingMessage);
          sendlogTG(loggingMessage)
          console.log(loggingMessage);
        } else {
          let loggingMessage = `❌ ${result.status}`;
          logMessage('scheduleCampaignAction', '1', loggingMessage);
          sendlogTG(loggingMessage)
          console.error(loggingMessage);
        }
      } catch (error) {
        let loggingMessage = `⚠️ Error executing ${action} for ${campaignId}: ${error}`;
        logMessage('scheduleCampaignAction', '1', loggingMessage);
        sendlogTG(loggingMessage)
        console.error(loggingMessage);
      }
    }, delay);

    this.jobs.set(jobId, timer);

    const actionText = action === 'pause' ? 'остановка' : action === 'restart' ? 'возобновление' : action;

    // Функция для преобразования delay в формат ЧЧ:ММ
// Функция для преобразования delay (в миллисекундах) в формат ЧЧ:ММ
    function formatDelay(ms) {
      const totalSeconds = Math.floor(ms / 1000);
      const hours = Math.floor(totalSeconds / 3600);
      const minutes = Math.floor((totalSeconds % 3600) / 60);
      return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}`;
    }
    let loggingMessage = `⏰ Запланирована ${actionText} для компании ${campaignId} (${crmname}) в ${timeStr} (через ${formatDelay(delay)})`;
    logMessage('scheduleCampaignAction', '1', loggingMessage);
    sendlogTG(loggingMessage)
    console.log(loggingMessage);
  }

  /**
   * Отменяет все задачи для кампании
   */
  cancelCampaignJobs(campaignId) {
    ['pause', 'restart'].forEach(action => {
      const jobId = `${action}_${campaignId}`;
      if (this.jobs.has(jobId)) {
        clearTimeout(this.jobs.get(jobId));
        this.jobs.delete(jobId);
      }
    });
    this.scheduledTimes.delete(campaignId);
    this.activeCampaigns.delete(campaignId);
  }
  /**
   * Рассчитывает задержку до указанного времени
   */
  calculateDelay(timeStr) {
    const [hours, minutes] = timeStr.split(':').map(Number);
    const now = new Date();
    const targetTime = new Date(
      now.getFullYear(),
      now.getMonth(),
      now.getDate(),
      hours,
      minutes
    );

    // Если время уже прошло, планируем на следующий день
    if (targetTime < now) {
      targetTime.setDate(targetTime.getDate() + 1);
    }

    return targetTime - now;
  }

  /**
  /**
   * Получает список активных кампаний
   */
  async getActiveCampaigns() {
    const { rows } = await pool.query(`
      SELECT advertid, crmname, pause_time, restart_time 
      FROM crm_headers 
      WHERE active = true
    `);
    return rows;
  }

  /**
   * Восстанавливает задачи при перезапуске сервера
   */
  async restoreScheduledJobs() {
    const campaigns = await this.getActiveCampaigns();
    for (const campaign of campaigns) {
      await this.scheduleCampaign(campaign);
    }
  }
}

// Экспортируем синглтон
const schedulerInstance = new SchedulerService();

// Восстанавливаем задания при инициализации
schedulerInstance.restoreScheduledJobs();

export default schedulerInstance;