//services/scheduler/campaign.actions.js
import axios from 'axios';
import { getApiKey } from '../auth.service.js';
export async function pauseCampaign(campaignId, apiKey = null) {
    try {
        const finalApiKey = apiKey || await getApiKey(campaignId);
        const response = await axios.get(
            'https://advert-api.wildberries.ru/adv/v0/pause',
            {
                params: { id: campaignId },
                headers: { 
                    Authorization: `Bearer ${finalApiKey}`
                }
            }
        );
        return {
            success: true,
            status: `Пауза для кампании ${campaignId} успешно активирована`,
            data: response.data
        };
    } catch (error) {
        return {
            success: false,
            status: `Ошибка паузы для ${campaignId}: ${error.response?.data?.message || error.message}`,
            error: error.response?.data || error.message
        };
    }
}

export async function restartCampaign(campaignId, apiKey = null) {
    try {
        const finalApiKey = apiKey || await getApiKey(campaignId);
        const response = await axios.get(
            'https://advert-api.wildberries.ru/adv/v0/start',
            {
                params: { id: campaignId },
                headers: { 
                    Authorization: `Bearer ${finalApiKey}`
                }
            }
        );
        
        return {
            success: true,
            status: `Рестарт кампании ${campaignId} успешно выполнен`,
            data: response.data
        };
    } catch (error) {
        return {
            success: false,
            status: `Ошибка рестарта для ${campaignId}: ${error.response?.data?.message || error.message}`,
            error: error.response?.data || error.message
        };
    }
}