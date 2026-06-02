export const removeByKeyValue = (array, key, value) => {
  return array.filter(item => item[key] !== value);
};

export default {
  removeByKeyValue
};