/**
 * mongosh CRUD 冒烟（独立库 mongosh_smoke_test，不影响 AgileConfig 库）
 * 运行示例：
 *   mongosh "mongodb://127.0.0.1:27017/mongosh_smoke_test" mongosh-crud-smoke.js
 * 带认证示例：
 *   mongosh "mongodb://user:pwd@host:27017/mongosh_smoke_test?authSource=admin" mongosh-crud-smoke.js
 */

const col = db.getCollection('crud_demo');

print('=== 清理历史冒烟数据 (_smoke=true) ===');
const delOld = col.deleteMany({ _smoke: true });
print('deleteMany matched: ' + delOld.deletedCount);

print('\n=== CREATE (insertOne) ===');
const ins = col.insertOne({
  _smoke: true,
  title: 'agileconfig-mongo-crud-smoke',
  value: 100,
  createdAt: new Date(),
});
printjson(ins);
const id = ins.insertedId;

print('\n=== READ (findOne) ===');
const doc1 = col.findOne({ _id: id });
printjson(doc1);
if (!doc1 || doc1.value !== 100) {
  throw new Error('READ 校验失败：未读到刚插入的文档或 value 不为 100');
}

print('\n=== UPDATE (updateOne + $set) ===');
const up = col.updateOne({ _id: id }, { $set: { value: 200, updatedAt: new Date() } });
printjson({ matchedCount: up.matchedCount, modifiedCount: up.modifiedCount });
const doc2 = col.findOne({ _id: id });
printjson(doc2);
if (!doc2 || doc2.value !== 200) {
  throw new Error('UPDATE 校验失败：value 应为 200');
}

print('\n=== DELETE (deleteOne) ===');
const del = col.deleteOne({ _id: id });
printjson({ deletedCount: del.deletedCount });
if (del.deletedCount !== 1) {
  throw new Error('DELETE 校验失败：deletedCount 应为 1');
}

print('\n=== VERIFY（应无 _smoke 文档）===');
const left = col.countDocuments({ _smoke: true });
print('countDocuments(_smoke:true) = ' + left);
if (left !== 0) {
  throw new Error('VERIFY 失败：仍残留 _smoke 文档');
}

print('\nCRUD smoke 全部通过。');
